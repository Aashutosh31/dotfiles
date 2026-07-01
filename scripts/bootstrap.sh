#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$HOME/dotfiles"

echo "======================================"
echo "      Dotfiles Bootstrap"
echo "======================================"

# Arch check
if ! command -v pacman >/dev/null 2>&1; then
    echo "This bootstrap script only supports Arch Linux."
    exit 1
fi

# Git
if ! command -v git >/dev/null 2>&1; then
    echo "Installing Git..."
    sudo pacman -Sy --needed git
fi

# yay
if ! command -v yay >/dev/null 2>&1; then
    echo "Installing yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
fi

# Clone repo
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Cloning dotfiles..."
    git clone https://github.com/Aashutosh31/dotfiles.git "$REPO_DIR"
else
    echo "Updating existing repository..."
    git -C "$REPO_DIR" pull
fi

cd "$REPO_DIR"

chmod +x install.sh
chmod +x scripts/*.sh

echo "Running installer..."
./install.sh

echo
echo "======================================"
echo " Bootstrap completed successfully!"
echo "======================================"