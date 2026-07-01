#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Backing up dotfiles..."

copy_config() {
    local name="$1"

    if [ -d "$HOME/.config/$name" ]; then
        rm -rf "$REPO/$name/.config/$name"
        mkdir -p "$REPO/$name/.config"
        cp -a "$HOME/.config/$name" "$REPO/$name/.config/"
        echo "✓ $name"
    fi
}

for cfg in \
alacritty atuin btop fastfetch ghostty hypr kitty lazydocker lazygit \
mise mpv nvim starship swayosd tmux voxtype walker waybar wiremix \
yazi zellij
do
    copy_config "$cfg"
done

cp ~/.zshrc "$REPO/home/.zshrc"
cp ~/.XCompose "$REPO/home/.XCompose"

echo
echo "Backup completed."