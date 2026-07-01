#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing official packages..."
sudo pacman -Syu --needed - < "$REPO/packages/pacman.txt"

if command -v yay >/dev/null 2>&1; then
    echo "==> Installing AUR packages..."
    yay -S --needed --answerclean None --answerdiff None - < "$REPO/packages/aur.txt"
else
    echo "yay not found. Skipping AUR packages."
fi

echo "==> Creating config directories..."
mkdir -p ~/.config

echo "==> Installing dotfiles..."

cp -r "$REPO/alacritty/.config/"* ~/.config/
cp -r "$REPO/atuin/.config/"* ~/.config/
cp -r "$REPO/btop/.config/"* ~/.config/
cp -r "$REPO/fastfetch/.config/"* ~/.config/
cp -r "$REPO/ghostty/.config/"* ~/.config/
cp -r "$REPO/hypr/.config/"* ~/.config/
cp -r "$REPO/kitty/.config/"* ~/.config/
cp -r "$REPO/lazydocker/.config/"* ~/.config/
cp -r "$REPO/lazygit/.config/"* ~/.config/
cp -r "$REPO/mise/.config/"* ~/.config/
cp -r "$REPO/mpv/.config/"* ~/.config/
cp -r "$REPO/nvim/.config/"* ~/.config/
cp -r "$REPO/starship/.config/"* ~/.config/
cp -r "$REPO/swayosd/.config/"* ~/.config/
cp -r "$REPO/tmux/.config/"* ~/.config/
cp -r "$REPO/voxtype/.config/"* ~/.config/
cp -r "$REPO/walker/.config/"* ~/.config/
cp -r "$REPO/waybar/.config/"* ~/.config/
cp -r "$REPO/wiremix/.config/"* ~/.config/
cp -r "$REPO/yazi/.config/"* ~/.config/
cp -r "$REPO/zellij/.config/"* ~/.config/

cp "$REPO/home/.zshrc" ~/
cp "$REPO/home/.XCompose" ~/

echo
echo "======================================"
echo " Dotfiles installed successfully."
echo "======================================"