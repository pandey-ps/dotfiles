#!/bin/bash
set -e
RICE="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  echo "!! do not run as root (makepkg forbids it, and configs would land in /root)."
  echo "   create a user and re-run as them:"
  echo "   useradd -m -G wheel <user> && passwd <user>"
  exit 1
fi

PACMAN_PKGS="hyprland hyprpaper waybar mako kitty fuzzel dolphin grim slurp brightnessctl wireplumber libpulse pavucontrol wdisplays jq libnotify neovim git base-devel wget curl pciutils seatd polkit networkmanager network-manager-applet"
AUR_PKGS="ttf-courier-prime python-pywal"
APT_PKGS="hyprland waybar mako kitty fuzzel dolphin grim slurp brightnessctl pavucontrol wdisplays pulseaudio-utils jq libnotify-bin neovim git build-essential wget curl seatd polkitd network-manager network-manager-gnome"
DNF_PKGS="hyprland hyprpaper waybar mako kitty fuzzel dolphin grim slurp brightnessctl wireplumber pavucontrol wdisplays pulseaudio-utils jq libnotify neovim git gcc make wget curl seatd polkit NetworkManager NetworkManager-applet"

PM=""
if command -v pacman >/dev/null; then PM="pacman"
elif command -v apt-get >/dev/null; then PM="apt"
elif command -v dnf >/dev/null; then PM="dnf"
fi
echo "==> package manager: ${PM:-none detected}"

if [ "$PM" = "pacman" ]; then
  sudo pacman -Syu --needed --noconfirm $PACMAN_PKGS

  if ! command -v yay >/dev/null; then
    echo "==> installing yay-bin (prebuilt AUR helper; avoids building yay from source)"
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
  fi
  echo "==> installing AUR packages (Courier Prime font, pywal for nvim colors)"
  yay -S --needed --noconfirm $AUR_PKGS || echo "!! AUR step failed, continuing (fallbacks cover both)"
elif [ "$PM" = "apt" ]; then
  echo "==> (no Courier Prime in apt; install manually: quoteunquoteapps.com/courierprime)"
  sudo apt-get update && sudo apt-get install -y $APT_PKGS || echo "!! some apt packages failed, continuing"
elif [ "$PM" = "dnf" ]; then
  echo "==> installing dnf packages"
  sudo dnf install -y $DNF_PKGS || echo "!! some dnf packages failed, continuing"
else
  echo "!! no supported package manager (pacman/apt/dnf); install the stack manually, then re-run"
  exit 1
fi

echo "==> seatd + polkit: Hyprland will not start without one of them"
sudo systemctl enable --now seatd 2>/dev/null || echo "!! could not enable seatd; ensure polkit is active"
sudo usermod -aG seat "$USER" 2>/dev/null || true

echo "==> installing configs (backups kept as *.bak)"
for d in hypr waybar mako kitty fuzzel nvim; do
  mkdir -p ~/.config/$d
  [ -e ~/.config/$d ] && [ ! -L ~/.config/$d ] && cp -a ~/.config/$d ~/.config/$d.bak 2>/dev/null || true
  cp -a "$RICE/.config/$d/." ~/.config/$d/
done
chmod +x ~/.config/waybar/scripts/*.sh 2>/dev/null || true
if [ -f ~/.config/hypr/hyprland.conf ] && [ ! -e ~/.config/hypr/hyprland.conf.bak ]; then
  mv ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
  echo "==> moved legacy hyprland.conf -> hyprland.conf.bak (using hyprland.lua)"
fi
mkdir -p ~/Pictures/Screenshots

echo "==> installing hyprctl wrapper (kills HYPRLAND_INSTANCE_SIGNATURE error"
echo "    from any shell; the env var is only set inside Hyprland sessions)"
mkdir -p ~/.local/bin
cp "$RICE/bin/hyprctl" ~/.local/bin/hyprctl
chmod +x ~/.local/bin/hyprctl
if sudo install -m755 "$RICE/bin/hyprctl" /usr/local/bin/hyprctl 2>/dev/null; then
  echo "==> wrapper installed system-wide (/usr/local/bin/hyprctl)"
else
  echo "!! sudo failed; using ~/.local/bin copy (ensure it is in your PATH)"
fi
for RC in ~/.bashrc ~/.zshrc; do
  [ -f "$RC" ] || continue
  if ! grep -q "export PATH=.*HOME/.local/bin" "$RC" 2>/dev/null; then
    cat >> "$RC" <<'EOF'

# dotfiles-hyprctl-path: make the hyprctl wrapper reachable
export PATH="$HOME/.local/bin:$PATH"
EOF
    echo "==> added PATH to $RC"
  else
    echo "==> PATH already set in $RC"
  fi
done

echo "==> installing vim-plug (then run :PlugInstall inside nvim)"
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' || echo "!! vim-plug download failed, continuing"

if command -v lspci >/dev/null && lspci 2>/dev/null | grep -qi "nvidia"; then
  if [ "$PM" = "pacman" ]; then
    echo "==> NVIDIA GPU detected: installing proprietary driver stack (Hyprland will not start without it)"
    HDRS=""
    for k in /boot/vmlinuz-*; do
      case "$k" in
        *-zen) HDRS="$HDRS linux-zen-headers" ;;
        *-lts) HDRS="$HDRS linux-lts-headers" ;;
        *-hardened) HDRS="$HDRS linux-hardened-headers" ;;
        *) HDRS="$HDRS linux-headers" ;;
      esac
    done
    sudo pacman -S --needed --noconfirm $HDRS nvidia-dkms nvidia-utils egl-wayland libva-nvidia-driver || echo "!! nvidia stack failed; install nvidia-dkms + headers manually"

    echo "==> enabling nvidia DRM modeset + fbdev"
    printf 'options nvidia_drm modeset=1 fbdev=1\n' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

    if [ -f /etc/mkinitcpio.conf ] && command -v mkinitcpio >/dev/null; then
      echo "==> early KMS: adding nvidia modules to mkinitcpio (backup: /etc/mkinitcpio.conf.pre-rice-bak)"
      sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.pre-rice-bak
      for m in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        sudo sed -i "s/^MODULES=(/MODULES=($m /;s/($m $m /($m /g" /etc/mkinitcpio.conf
      done
      sudo mkinitcpio -P || echo "!! mkinitcpio rebuild failed; run sudo mkinitcpio -P manually"
    fi

    if [ -d ~/.config/uwsm ] || command -v uwsm >/dev/null; then
      echo "==> uwsm detected: NVIDIA env goes to ~/.config/uwsm/env (per Hyprland wiki)"
      mkdir -p ~/.config/uwsm
      grep -q "LIBVA_DRIVER_NAME" ~/.config/uwsm/env 2>/dev/null || cat >> ~/.config/uwsm/env <<'EOF'
export LIBVA_DRIVER_NAME=nvidia
export __GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
    fi
    echo "==> NVIDIA done: REBOOT is required, then verify:"
    echo "    cat /sys/module/nvidia_drm/parameters/modeset   (want: Y)"
  else
    echo "==> NVIDIA GPU detected but distro is not Arch: install the proprietary"
    echo "    driver + egl-wayland manually and enable nvidia_drm.modeset=1."
  fi
fi

echo "==> enabling network"
sudo systemctl enable --now NetworkManager 2>/dev/null || true

echo "done. Hyprland is installed but NOT running (that is why hyprctl errored)."
echo "1) log out of this session (or reboot) so the seat group applies"
echo "2) at the tty1 login as your user, run:  start-hyprland"
echo "   (or install/enable a display manager, e.g. sudo pacman -S sddm && sudo systemctl enable sddm,"
echo "    then pick the 'Hyprland' session at the login screen)"
echo "3) if Hyprland is on another console, jump to it with:  sudo chvt 1"
echo "   (plain hyprctl now works from any shell via the wrapper; never use sudo hyprctl,"
echo "    root cannot reach your session socket)"
echo "keys: Super+Return terminal, Super+Space launcher, Super+W kill, Super+1..0 workspaces, Print screenshot."
