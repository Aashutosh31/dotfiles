#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="https://github.com/Aashutosh31/dotfiles.git"

echo "======================================"
echo "      Dotfiles Bootstrap"
echo "======================================"

# --- 1. Verify Arch Linux ---
if ! command -v pacman &>/dev/null; then
    echo "ERROR: This script requires Arch Linux (pacman not found)."
    exit 1
fi

# --- 2. Install git if missing ---
if ! command -v git &>/dev/null; then
    echo "==> Installing git..."
    sudo pacman -Sy --noconfirm --needed git
fi

# --- 3. Install yay if missing ---
if ! command -v yay &>/dev/null; then
    echo "==> Installing yay (AUR helper)..."
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
fi

# --- 4. Clone or update the repository ---
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    if [ -d "$DOTFILES_DIR" ]; then
        echo "ERROR: $DOTFILES_DIR exists but is not a git repository."
        echo "       Remove or rename it first, then re-run this script."
        exit 1
    fi
    echo "==> Cloning dotfiles to $DOTFILES_DIR..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
else
    echo "==> Updating existing dotfiles repository..."
    if ! git -C "$DOTFILES_DIR" pull --ff-only; then
        echo "WARNING: git pull failed. Using existing copy in $DOTFILES_DIR."
        echo "         Run 'git -C $DOTFILES_DIR pull' manually to resolve."
    fi
fi

# --- 5. Make scripts executable ---
chmod +x "$DOTFILES_DIR/install.sh"
chmod +x "$DOTFILES_DIR/scripts/"*.sh 2>/dev/null || true

# --- 6. Hand off to install.sh ---
echo "==> Running installer..."
if ! "$DOTFILES_DIR/install.sh"; then
    echo
    echo "ERROR: install.sh failed. Check the output above for details."
    exit 1
fi

echo
echo "======================================"
echo " Bootstrap completed successfully!"
echo "======================================"
