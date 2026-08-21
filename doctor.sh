#!/usr/bin/env bash
#
# doctor.sh — READ-ONLY diagnosis of this dotfiles installation.
#
# Reports missing packages/commands, wrong login shell, missing shell
# initialization (~/.local/bin/env), broken symlinks and config drift.
# It NEVER writes, deletes or installs anything.
#
# Exit codes: 0 = all required components present, 1 = at least one FAIL.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/shell-env.sh
source "$REPO/scripts/lib/shell-env.sh"

PASS=0 WARN=0 FAIL=0

ok()   { printf '  [ OK ] %s\n' "$1"; PASS=$((PASS + 1)); }
warn() { printf '  [WARN] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

header() { printf '\n== %s ==\n' "$1"; }

echo "dotfiles doctor (read-only) — repo: $REPO"
echo "user: $(id -un)  home: $HOME"

# ---------------------------------------------------------------
# System base
# ---------------------------------------------------------------
header "System"
if command -v pacman &>/dev/null; then
    ok "Arch Linux detected (pacman present)"
else
    fail "pacman not found — this setup targets Arch/Omarchy"
fi
if grep -ri omarchy /usr/share/omarchy/version /etc/os-release 2>/dev/null | grep -q . \
    || [ -d /usr/share/omarchy ]; then
    ok "Omarchy detected"
else
    warn "Omarchy not detected (mise shims PATH wiring comes from /etc/profile.d/omarchy.sh)"
fi
if [ -r /usr/share/omarchy/default/bash/env-bootstrap ]; then
    ok "Omarchy PATH bootstrap present (adds ~/.local/share/mise/shims and ~/.local/bin to PATH on login)"
else
    warn "/usr/share/omarchy/default/bash/env-bootstrap not readable — mise shims may need manual PATH setup"
fi

# ---------------------------------------------------------------
# Required packages
# ---------------------------------------------------------------
header "Required packages"
missing=""
for p in "${REQUIRED_PKGS[@]}"; do
    if pkg_installed "$p"; then
        ok "package installed: $p"
    else
        fail "package MISSING: $p"
        missing+="$p "
    fi
done
for p in "${RECOMMENDED_PKGS[@]}"; do
    if pkg_installed "$p"; then
        ok "recommended package installed: $p"
    elif command -v "$p" &>/dev/null; then
        ok "recommended tool available (not via pacman): $p"
    else
        case "$p" in
            uv)   warn "recommended package absent: uv (creator of ~/.local/bin/env; install via astral.sh/uv/install.sh)" ;;
            fish) warn "recommended package absent: fish (foot.ini sets shell=fish; other terminals use zsh)" ;;
            *)    warn "recommended package absent: $p (optional)" ;;
        esac
    fi
done

# ---------------------------------------------------------------
# Commands resolvable
# ---------------------------------------------------------------
header "Commands"
for c in zsh starship zoxide atuin yazi mise eza bat fd fzf git; do
    if p="$(command -v "$c" 2>/dev/null)" && [ -x "$p" ]; then
        ok "$c -> $p"
    else
        if printf '%s' " $missing " | grep -q " $c "; then
            : # already reported as a missing package
        else
            fail "command not found: $c"
        fi
    fi
done

# ---------------------------------------------------------------
# Zsh availability & login shell selection
# ---------------------------------------------------------------
header "Zsh / login shell"
ZSH_BIN="$(command -v zsh 2>/dev/null || true)"
if [ -n "$ZSH_BIN" ] && [ -x "$ZSH_BIN" ]; then
    ok "zsh binary present at $ZSH_BIN"
else
    fail "zsh binary not found"
fi
for zp in /bin/zsh /usr/bin/zsh; do
    [ -e "$zp" ] && ok "$zp exists" || fail "$zp missing"
done
if etc_shells_has_zsh; then
    ok "zsh listed in /etc/shells"
else
    fail "zsh NOT listed in /etc/shells (chsh will refuse it)"
fi
CUR_SHELL="$(current_login_shell)"
if login_shell_is_zsh; then
    ok "login shell for $(id -un) is zsh ($CUR_SHELL)"
else
    fail "login shell for $(id -un) is '${CUR_SHELL:-<unset>}', expected zsh — terminals will open bash and .zshrc cannot run"
fi

# ---------------------------------------------------------------
# Shell initialization files
# ---------------------------------------------------------------
header "Shell initialization"
if [ -r "$HOME/.local/bin/env" ]; then
    ok "$HOME/.local/bin/env present (sourced by the last line of .zshrc)"
else
    fail "$HOME/.local/bin/env MISSING — written by uv's standalone installer;"
    fail "  without it every zsh startup ends with: $HOME/.local/share/../bin/env: No such file or directory"
fi
if [ -r "$HOME/.local/bin/env.fish" ]; then
    ok "$HOME/.local/bin/env.fish present (sourced by fish conf.d/uv.env.fish)"
else
    fail "$HOME/.local/bin/env.fish MISSING — fish startup will error too"
fi
if [ -f "$HOME/.zshrc" ]; then
    ok "~/.zshrc present"
else
    fail "~/.zshrc MISSING"
fi
for f in "${ZSH_PLUGIN_FILES[@]}"; do
    [ -r "$f" ] && ok "plugin present: $f" || fail "plugin MISSING: $f (install zsh-autosuggestions / zsh-syntax-highlighting)"
done

# ---------------------------------------------------------------
# Installed configs vs repo
# ---------------------------------------------------------------
header "Installed config drift"
for entry in "${SHELL_CONFIG_MAP[@]}"; do
    src="$REPO/${entry%%|*}"
    dest="${entry#*|}"
    if [ ! -e "$src" ]; then
        warn "repo file/dir missing: $src"
        continue
    fi
    if [ -f "$src" ]; then
        if [ ! -f "$dest" ]; then
            if [ "$(basename "$dest")" = ".zshrc" ]; then
                fail "installed file missing: $dest"
            else
                warn "installed file missing: $dest"
            fi
        elif cmp -s "$src" "$dest"; then
            ok "$dest matches repo"
        else
            warn "$dest DIFFERS from repo (run ./repair.sh to re-apply)"
        fi
    else
        drift=0 absent=0 total=0
        while IFS= read -r -d '' file; do
            rel="${file#"$src"/}"
            total=$((total + 1))
            if [ ! -f "$dest/$rel" ]; then
                absent=$((absent + 1))
            elif ! cmp -s "$file" "$dest/$rel"; then
                drift=$((drift + 1))
            fi
        done < <(find "$src" -type f -print0)
        if [ "$absent" -gt 0 ]; then
            warn "$dest: $absent of $total repo files not installed"
        elif [ "$drift" -gt 0 ]; then
            warn "$dest: $drift of $total files differ from repo (run ./repair.sh to re-apply)"
        else
            ok "$dest matches repo ($total files)"
        fi
    fi
done

# ---------------------------------------------------------------
# Broken symlinks in ~/.config
# ---------------------------------------------------------------
header "Broken symlinks"
broken="$(find "$HOME/.config" -xtype l -print 2>/dev/null)"
if [ -z "$broken" ]; then
    ok "no broken symlinks under ~/.config"
else
    count="$(printf '%s\n' "$broken" | wc -l)"
    warn "$count broken symlink(s) under ~/.config:"
    printf '%s\n' "$broken" | head -20 | sed 's/^/         /'
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
printf '\n== Summary ==\n'
printf '  OK: %d   WARN: %d   FAIL: %d\n' "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo
    echo "RESULT: BROKEN — fix the [FAIL] items above (./repair.sh fixes them automatically)."
    echo "Remember: zsh is REQUIRED. After changing the login shell, start a NEW login session."
    exit 1
fi

echo
echo "RESULT: HEALTHY — all required components present.$([ "$WARN" -gt 0 ] && printf ' (%d warning(s).)' "$WARN")"
exit 0
