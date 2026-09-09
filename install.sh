#!/bin/bash
set -e
RICE="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  echo "!! do not run as root (makepkg forbids it, and configs would land in /root)."
  echo "   create a user and re-run as them:"
  echo "   useradd -m -G wheel <user> && passwd <user>"
  exit 1
fi

PACMAN_PKGS="hyprland hyprpaper waybar mako kitty fuzzel dolphin grim slurp brightnessctl wireplumber libpulse wdisplays libnotify neovim git base-devel wget curl pciutils seatd polkit networkmanager"
AUR_PKGS="ttf-courier-prime python-pywal"
APT_PKGS="hyprland waybar mako kitty fuzzel dolphin grim slurp brightnessctl wdisplays pulseaudio-utils libnotify-bin neovim git build-essential wget curl seatd polkitd network-manager"
DNF_PKGS="hyprland hyprpaper waybar mako kitty fuzzel dolphin grim slurp brightnessctl wireplumber wdisplays pulseaudio-utils libnotify neovim git gcc make wget curl seatd polkit NetworkManager"

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

for d in hypr waybar mako kitty fuzzel nvim; do
  mkdir -p ~/.config/$d
  [ -e ~/.config/$d ] && [ ! -L ~/.config/$d ] && cp -a ~/.config/$d ~/.config/$d.bak 2>/dev/null || true
  cp -a "$RICE/.config/$d/." ~/.config/$d/
done
chmod +x ~/.config/waybar/scripts/*.sh 2>/dev/null || true
if [ -f ~/.config/hypr/hyprland.conf ] && [ ! -e ~/.config/hypr/hyprland.conf.bak ]; then
  mv ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
fi
mkdir -p ~/Pictures/Screenshots
mkdir -p ~/Pictures/Wallpapers
cp -a "$RICE/wallpapers/." ~/Pictures/Wallpapers/

mkdir -p ~/.local/bin
cp "$RICE/bin/hyprctl" ~/.local/bin/hyprctl
chmod +x ~/.local/bin/hyprctl
sudo install -m755 "$RICE/bin/hyprctl" /usr/local/bin/hyprctl 2>/dev/null || true
for RC in ~/.bashrc ~/.zshrc; do
  [ -f "$RC" ] || continue
  if ! grep -q "export PATH=.*HOME/.local/bin" "$RC" 2>/dev/null; then
    cat >> "$RC" <<'EOF'

export PATH="$HOME/.local/bin:$PATH"
EOF
  fi
done

sh -c 'curl -fsSL -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' || true

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

echo "launch with:  start-hyprland"
echo "keys: Super+Return terminal, Super+Space launcher, Super+W kill, Super+1..0 workspaces"
