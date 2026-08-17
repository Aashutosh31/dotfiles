#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================
# Stage 1/3: Official packages (pacman)
# =============================================
echo
echo "==> Stage 1/3: Installing official packages (pacman)..."
if ! sudo pacman -Syu --needed - < "$REPO/packages/pacman.txt"; then
    echo
    echo "ERROR: Official package installation (pacman) failed."
    echo "       Check the output above for details."
    exit 1
fi

# =============================================
# Stage 2/3: AUR packages (yay)
# =============================================
echo
echo "==> Stage 2/3: Installing AUR packages (yay)..."
if command -v yay &>/dev/null; then
    if ! yay -S --needed --answerclean None --answerdiff None - < "$REPO/packages/aur.txt"; then
        echo
        echo "ERROR: AUR package installation (yay) failed."
        echo "       Check the output above for details."
        exit 1
    fi
else
    echo "WARNING: yay not found. Skipping AUR packages."
    echo "         Install yay first, then re-run this script."
    exit 1
fi

# =============================================
# Stage 3/3: Configuration files
# =============================================
echo
echo "==> Stage 3/3: Installing configuration files..."

backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

backup_item() {
    if [ -e "$1" ]; then
        mkdir -p "$backup$(dirname "$1")"
        cp -a "$1" "$backup$1"
    fi
}

install_cfg() {
    local cfg="$1"

    if [ -d "$REPO/$cfg/.config/$cfg" ]; then
        backup_item "$HOME/.config/$cfg"
        rm -rf "$HOME/.config/$cfg"
        mkdir -p "$HOME/.config"
        cp -a "$REPO/$cfg/.config/$cfg" "$HOME/.config/"
    fi
}

for cfg in \
alacritty atuin btop fastfetch fish foot ghostty hypr kitty lazydocker \
lazygit mise mpv nvim omarchy tmux voxtype yazi zellij
do
    install_cfg "$cfg"
done

# Starship lives at ~/.config/starship.toml (not ~/.config/starship/)
backup_item "$HOME/.config/starship.toml"
cp -f "$REPO/starship/.config/starship.toml" "$HOME/.config/starship.toml"

# The wallhaven theme's background is tracked once under wallpapers/
mkdir -p "$HOME/.config/omarchy/themes/wallhaven/backgrounds"
cp -f "$REPO/wallpapers/wallhaven.png" "$HOME/.config/omarchy/themes/wallhaven/backgrounds/wallhaven.png"

# Custom About screen launcher
backup_item "$HOME/.local/bin/omarchy-launch-about"
mkdir -p "$HOME/.local/bin"
cp -f "$REPO/scripts/omarchy-launch-about" "$HOME/.local/bin/omarchy-launch-about"
chmod +x "$HOME/.local/bin/omarchy-launch-about"

backup_item "$HOME/.zshrc"
backup_item "$HOME/.XCompose"

cp -f "$REPO/home/.zshrc" "$HOME/"
cp -f "$REPO/home/.XCompose" "$HOME/"

echo
echo "======================================"
echo " Dotfiles installed successfully!"
echo " Backup saved to:"
echo " $backup"
echo "======================================"
