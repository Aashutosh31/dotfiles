#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================
# Stage 1/4: Missing official packages (pacman)
# =============================================
#
# This installer deliberately does NOT run a full system upgrade (-Syu).
# On Omarchy, direct system upgrades must go through 'omarchy update'
# (enforced by the Omarchy ALPM guard hook), so we only ensure that the
# packages listed in packages/pacman.txt are present.
mapfile -t official_pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$REPO/packages/pacman.txt")

if [ "${#official_pkgs[@]}" -eq 0 ]; then
    echo
    echo "ERROR: packages/pacman.txt contains no package names."
    exit 1
fi

echo
echo "==> Stage 1/4: Installing missing official packages (${#official_pkgs[@]} total)..."

if command -v omarchy-pkg-add &>/dev/null; then
    # Preferred path on Omarchy: installs only packages that are absent,
    # then verifies every requested package is actually installed.
    if ! omarchy-pkg-add "${official_pkgs[@]}"; then
        echo
        echo "ERROR: Official package installation (omarchy-pkg-add) failed."
        echo "       Check the output above for details."
        exit 1
    fi
elif command -v pacman &>/dev/null; then
    # Fallback for non-Omarchy Arch: install requested packages without
    # refreshing databases or upgrading anything already installed.
    echo "==> omarchy-pkg-add not found, falling back to 'pacman -S --needed'..."
    if ! sudo pacman -S --needed "${official_pkgs[@]}"; then
        echo
        echo "ERROR: Official package installation (pacman) failed."
        echo "       Check the output above for details."
        exit 1
    fi
else
    echo
    echo "ERROR: Neither omarchy-pkg-add nor pacman found."
    exit 1
fi

echo "==> Official packages OK."

# =============================================
# Stage 2/4: AUR packages (yay)
# =============================================
echo
echo "==> Stage 2/4: Installing AUR packages (yay)..."
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
# Stage 3/4: Configuration files
# =============================================
echo
echo "==> Stage 3/4: Installing configuration files..."

backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

backup_item() {
    if [ -e "$1" ]; then
        mkdir -p "$backup$(dirname "$1")"
        cp -a "$1" "$backup$1"
    fi
}

# Per-file in-place replacement.
#
# Instead of deleting-and-replacing an entire directory (which leaves a
# window where the directory is missing), we iterate over every file in
# the repo source and overwrite each one individually inside the live
# config directory.  The directory itself is never touched — only its
# contents are updated.  Files that exist only in the live config are
# left in place (no deletion during a live session).
install_cfg() {
    local cfg="$1"
    local src="$REPO/$cfg/.config/$cfg"
    local dest="$HOME/.config/$cfg"

    if [ ! -d "$src" ]; then
        return
    fi

    mkdir -p "$dest"

    while IFS= read -r -d '' file; do
        local rel="${file#"$src"/}"
        local target="$dest/$rel"

        # Back up the live file before overwriting.
        backup_item "$target"

        # Ensure the target subdirectory exists.
        mkdir -p "$(dirname "$target")"

        # Overwrite the live file in-place.
        cp -a "$file" "$target"
    done < <(find "$src" -type f -print0)
}

for cfg in \
alacritty atuin btop fastfetch fish foot ghostty hypr kitty lazydocker \
lazygit mise mpv nvim omarchy tmux voxtype yazi zellij
do
    install_cfg "$cfg"
done

# Validate Hyprland config if the compositor is running.
if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
    echo "==> Validating Hyprland configuration..."
    errors="$(hyprctl configerrors 2>/dev/null)"
    if [ -n "$errors" ]; then
        echo "    WARNING: Hyprland reports config errors:"
        echo "$errors" | sed 's/^/      /'
        echo "    Check ~/.config/hypr/ manually."
    else
        echo "    Hyprland config looks valid (no parse errors)."
    fi
    echo
    echo "    NOTE: Config changes will take effect after you run:"
    echo "          hyprctl reload"
    echo "    Or log out and back in."
    echo
fi

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

# =============================================
# Stage 4/4: Shell environment (zsh + PATH bootstrap)
# =============================================
#
# Copying .zshrc alone does not give you a working shell: zsh must be the
# login shell, and ~/.local/bin/env (normally written by uv's standalone
# installer) must exist because the last line of .zshrc sources it.
source "$REPO/scripts/lib/shell-env.sh"

echo
echo "==> Stage 4/4: Setting up the shell environment..."
env_failures=0

if ! ensure_zsh_in_etc_shells; then
    echo "    WARNING: could not add zsh to /etc/shells."
    env_failures=$((env_failures + 1))
fi

if ! ensure_login_shell_is_zsh; then
    echo "    WARNING: could not set zsh as the login shell."
    echo "    Run it manually later with: chsh -s \"$(command -v zsh 2>/dev/null || echo /bin/zsh)\""
    env_failures=$((env_failures + 1))
fi

if ! ensure_local_bin_env "$backup"; then
    echo "    WARNING: could not create ~/.local/bin/env."
    env_failures=$((env_failures + 1))
fi

missing_cmds=""
for cmd in "${REQUIRED_PKGS[@]}"; do
    command -v "$cmd" &>/dev/null || missing_cmds+="$cmd "
done
if [ -n "$missing_cmds" ]; then
    echo "    WARNING: these commands are still not on PATH: $missing_cmds"
    echo "             (package stage may have failed — check output above,"
    echo "              or run ./doctor.sh / ./repair.sh afterwards)"
fi

echo
echo "======================================"
echo " Dotfiles installed successfully!"
echo " Backup saved to:"
echo " $backup"
echo "======================================"
echo
echo " If you are running Hyprland, run 'hyprctl reload' to apply"
echo " any config changes without logging out."
if [ "$env_failures" -gt 0 ]; then
    echo
    echo " NOTE: $env_failures shell-environment step(s) reported problems above —"
    echo "       fix them or run ./repair.sh before opening a new terminal."
else
    echo
    echo " Zsh environment is ready. Open a NEW terminal to use it"
    echo " (the login-shell change only applies to new sessions)."
fi
