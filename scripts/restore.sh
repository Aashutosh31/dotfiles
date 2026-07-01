#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Restoring dotfiles..."

mkdir -p ~/.config

restore_config() {
    local name="$1"

    if [ -d "$REPO/$name/.config/$name" ]; then
        mkdir -p "$HOME/.config"
        cp -a "$REPO/$name/.config/$name" "$HOME/.config/"
        echo "✓ $name"
    fi
}

for cfg in \
alacritty atuin btop fastfetch ghostty hypr kitty lazydocker lazygit \
mise mpv nvim starship swayosd tmux voxtype walker waybar wiremix \
yazi zellij
do
    restore_config "$cfg"
done

cp -f "$REPO/home/.zshrc" ~/
cp -f "$REPO/home/.XCompose" ~/

echo
echo "Restore completed."