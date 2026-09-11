#!/bin/bash
set -e
RICE="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  echo "!! do not run as root (makepkg forbids it, and configs would land in /root)."
  echo "   create a user and re-run as them:"
  echo "   useradd -m -G wheel <user> && passwd <user>"
  exit 1
fi

PACMAN_PKGS="hyprland hyprpaper hyprlock hypridle waybar mako alacritty fuzzel nautilus grim slurp brightnessctl wireplumber pipewire-audio pipewire-pulse sof-firmware power-profiles-daemon python-gobject libpulse wdisplays cliphist wl-clipboard fastfetch btop imv mpv noto-fonts-emoji starship xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk libnotify neovim git base-devel curl pciutils seatd polkit networkmanager"
AUR_PKGS="ttf-courier-prime python-pywal"
APT_PKGS="hyprland waybar mako alacritty fuzzel nautilus grim slurp brightnessctl pipewire-pulse firmware-sof-signed power-profiles-daemon python3-gi wdisplays cliphist wl-clipboard fastfetch btop imv mpv fonts-noto-color-emoji starship xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprlock hypridle pulseaudio-utils libnotify-bin neovim git build-essential curl seatd polkitd network-manager"
DNF_PKGS="hyprland hyprpaper hyprlock hypridle waybar mako alacritty fuzzel nautilus grim slurp brightnessctl wireplumber pipewire-pulseaudio alsa-sof-firmware power-profiles-daemon python3-gobject wdisplays cliphist wl-clipboard fastfetch btop imv starship google-noto-emoji-color-fonts xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk pulseaudio-utils libnotify neovim git gcc make curl seatd polkit NetworkManager"

PM=""
if command -v pacman >/dev/null; then PM="pacman"
elif command -v apt-get >/dev/null; then PM="apt"
elif command -v dnf >/dev/null; then PM="dnf"
fi

if [ "$PM" = "pacman" ]; then
  sudo pacman -Syu --needed --noconfirm $PACMAN_PKGS

  if ! command -v yay >/dev/null; then
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
  fi
  yay -S --needed --noconfirm $AUR_PKGS || true
elif [ "$PM" = "apt" ]; then
  sudo apt-get update && sudo apt-get install -y $APT_PKGS || true
elif [ "$PM" = "dnf" ]; then
  sudo dnf install -y $DNF_PKGS || true
else
  echo "!! no supported package manager (pacman/apt/dnf); install the stack manually, then re-run"
  exit 1
fi

sudo systemctl enable --now seatd 2>/dev/null || true
sudo usermod -aG seat "$USER" 2>/dev/null || true

# tty1 autologin so the machine boots straight into Hyprland
# (companion piece: ~/.bash_profile execs start-hyprland on tty1)
if command -v systemctl >/dev/null 2>&1; then
  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin $USER %I \$TERM
EOF
  sudo systemctl daemon-reload 2>/dev/null || true
fi

for d in hypr waybar mako alacritty starship fuzzel nvim; do
  mkdir -p ~/.config/$d
  [ -e ~/.config/$d ] && [ ! -L ~/.config/$d ] && cp -a ~/.config/$d ~/.config/$d.bak 2>/dev/null || true
  cp -a "$RICE/.config/$d/." ~/.config/$d/
done
chmod +x ~/.config/waybar/scripts/*.sh 2>/dev/null || true
mkdir -p ~/.local/share/applications
cp "$RICE"/applications/*.desktop ~/.local/share/applications/ 2>/dev/null || true
if [ -f ~/.config/hypr/hyprland.conf ] && [ ! -e ~/.config/hypr/hyprland.conf.bak ]; then
  mv ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
fi
mkdir -p ~/Pictures/Screenshots

mkdir -p ~/.local/bin
cp "$RICE/bin/hyprctl" ~/.local/bin/hyprctl
cp "$RICE/bin/konsole" ~/.local/bin/konsole
cp "$RICE/bin/opencode" ~/.local/bin/opencode
chmod +x ~/.local/bin/hyprctl ~/.local/bin/konsole ~/.local/bin/opencode
sudo install -m755 "$RICE/bin/hyprctl" /usr/local/bin/hyprctl 2>/dev/null || true
sudo install -m755 "$RICE/bin/konsole" /usr/local/bin/konsole 2>/dev/null || true
for RC in ~/.bashrc ~/.zshrc; do
  [ -f "$RC" ] || continue
  if ! grep -q "export PATH=.*HOME/.local/bin" "$RC" 2>/dev/null; then
    cat >> "$RC" <<'EOF'

export PATH="$HOME/.local/bin:$PATH"
EOF
  fi
done

sh -c 'curl -fsSL -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' || true

# generate pywal colors and install nvim plugins so the wal theme works
if command -v wal >/dev/null 2>&1; then
  wal -i "$RICE/wallpapers/backwater.jpg" -n >/dev/null 2>&1 || true
fi
if command -v nvim >/dev/null 2>&1; then
  nvim --headless "+PlugInstall --sync" "+qall" >/dev/null 2>&1 || true
fi

if command -v lspci >/dev/null && lspci 2>/dev/null | grep -qi "nvidia"; then
  if [ "$PM" = "pacman" ]; then
    HDRS=""
    for k in /boot/vmlinuz-*; do
      case "$k" in
        *-zen) HDRS="$HDRS linux-zen-headers" ;;
        *-lts) HDRS="$HDRS linux-lts-headers" ;;
        *-hardened) HDRS="$HDRS linux-hardened-headers" ;;
        *) HDRS="$HDRS linux-headers" ;;
      esac
    done
    sudo pacman -S --needed --noconfirm $HDRS nvidia-dkms nvidia-utils egl-wayland libva-nvidia-driver || true

    printf 'options nvidia_drm modeset=1 fbdev=1\n' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

    if [ -f /etc/mkinitcpio.conf ] && command -v mkinitcpio >/dev/null; then
      sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.pre-rice-bak
      for m in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        sudo sed -i "s/^MODULES=(/MODULES=($m /;s/($m $m /($m /g" /etc/mkinitcpio.conf
      done
      sudo mkinitcpio -P || true
    fi

    if [ -d ~/.config/uwsm ] || command -v uwsm >/dev/null; then
      mkdir -p ~/.config/uwsm
      grep -q "LIBVA_DRIVER_NAME" ~/.config/uwsm/env 2>/dev/null || cat >> ~/.config/uwsm/env <<'EOF'
export LIBVA_DRIVER_NAME=nvidia
export __GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
    fi
  fi
fi

sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now power-profiles-daemon 2>/dev/null || true
sudo timedatectl set-timezone Asia/Kolkata 2>/dev/null || true

echo "launch with:  start-hyprland"
echo "keys: Super+Return terminal, Super+Space launcher, Super+W kill, Super+1..0 workspaces"
