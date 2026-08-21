#!/usr/bin/env bash
#
# repair.sh — safe, idempotent repair of an existing dotfiles installation.
#
# Fixes a shell environment that is broken after a partial install (e.g. on a
# fresh Omarchy system) WITHOUT reinstalling the OS or re-running install.sh:
#
#   1. installs ONLY the required packages that are actually missing
#   2. ensures zsh is installed and listed in /etc/shells
#   3. sets the login shell to zsh — only when it isn't already; prints a clear
#      message and reminds you to start a NEW login session afterwards
#   4. recreates ~/.local/bin/env (+ env.fish) when missing (uv standalone-
#      installer template; uv itself is not touched)
#   5. re-applies only the shell-related configs (.zshrc, .XCompose, starship,
#      fish, mise, atuin), backing up any file before overwriting it
#
# Never runs a system upgrade (no pacman/yay -Syu), never deletes user data or
# config directories, and can be run any number of times — unchanged state is
# skipped with [SKIP].

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/shell-env.sh
source "$REPO/scripts/lib/shell-env.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "run as your normal user; sudo is invoked automatically only where needed"
command -v pacman &>/dev/null || die "this repair targets Arch Linux (pacman not found)"

backup_root="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)-repair"

echo "======================================"
echo "      Dotfiles Repair"
echo "======================================"

# ---------------------------------------------------------------
# 1/5 Required packages (only the ones that are missing)
# ---------------------------------------------------------------
echo
echo "==> Step 1/5: Checking required packages..."
to_install="$(missing_required_pkgs)"
if [ -z "$to_install" ]; then
    echo "[SKIP]     all ${#REQUIRED_PKGS[@]} required packages already installed"
else
    # shellcheck disable=SC2086
    mapfile -t pkgs <<< "$to_install"
    echo "==> Installing missing packages: ${pkgs[*]}"
    if command -v omarchy-pkg-add &>/dev/null; then
        omarchy-pkg-add "${pkgs[@]}" || die "package installation failed (omarchy-pkg-add)"
    else
        sudo pacman -S --needed --noconfirm "${pkgs[@]}" || die "package installation failed (pacman)"
    fi
    leftovers="$(missing_required_pkgs)"
    [ -n "$leftovers" ] && die "still missing after install: $leftovers"
fi

# ---------------------------------------------------------------
# 2/5 zsh in /etc/shells
# ---------------------------------------------------------------
echo
echo "==> Step 2/5: Ensuring zsh is available as a login shell..."
command -v zsh &>/dev/null || die "zsh still not found after package step"
ensure_zsh_in_etc_shells || die "could not update /etc/shells"

# ---------------------------------------------------------------
# 3/5 Login shell -> zsh (only when necessary)
# ---------------------------------------------------------------
echo
echo "==> Step 3/5: Checking login shell..."
if ! ensure_login_shell_is_zsh; then
    die "login shell could not be set to zsh; set it manually with: chsh -s \"$(command -v zsh)\""
fi

# ---------------------------------------------------------------
# 4/5 ~/.local/bin/env (+ env.fish)
# ---------------------------------------------------------------
echo
repair_uv_env_files "$backup_root" || die "could not create ~/.local/bin/env"

# ---------------------------------------------------------------
# 5/5 Re-apply shell-related configs from the repo
# ---------------------------------------------------------------
echo
echo "==> Step 5/5: Re-applying shell configurations from repo..."
reapply_shell_configs "$REPO" "$backup_root" || die "config re-apply reported an error"

# ---------------------------------------------------------------
# Final verification
# ---------------------------------------------------------------
echo
echo "==> Verifying repaired environment..."
problems=0
for c in "${REQUIRED_PKGS[@]}"; do
    command -v "$c" &>/dev/null || { echo "  [FAIL] command still missing: $c"; problems=$((problems + 1)); }
done
[ -r "$HOME/.local/bin/env" ] || { echo "  [FAIL] $HOME/.local/bin/env still missing"; problems=$((problems + 1)); }
etc_shells_has_zsh || { echo "  [FAIL] zsh not listed in /etc/shells"; problems=$((problems + 1)); }
login_shell_is_zsh || { echo "  [FAIL] login shell is not zsh yet ($(current_login_shell))"; problems=$((problems + 1)); }

if [ "$problems" -gt 0 ]; then
    echo
    echo "RESULT: INCOMPLETE — $problems problem(s) remain. See output above."
    exit 1
fi

echo
echo "======================================"
echo " Repair complete — environment healthy."
echo "======================================"
echo
echo "Open a NEW terminal (or log out and back in) to get your full Zsh setup."
echo "Run ./doctor.sh anytime for a read-only health check."
exit 0
