#!/usr/bin/env bash
#
# scripts/lib/shell-env.sh
#
# Shared shell-environment helpers sourced by install.sh, repair.sh and
# doctor.sh. Scope: everything the interactive shell needs to come up in the
# same state as the author's machine:
#
#   - zsh present, listed in /etc/shells, and selected as the user's login shell
#   - ~/.local/bin/env and ~/.local/bin/env.fish (normally written by uv's
#     standalone installer; recreated verbatim here when missing)
#   - the small set of packages/configs .zshrc hard-depends on
#
# Zsh is REQUIRED for this dotfiles setup: .zshrc uses zsh-only builtins
# (setopt/autoload/bindkey), zsh plugins loaded from /usr/share/zsh/plugins,
# starship/zoxide/atuin `init zsh` hooks, and ends by sourcing
# ~/.local/share/../bin/env (= ~/.local/bin/env).

# Packages without which .zshrc errors or core aliases break.
REQUIRED_PKGS=(
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    starship        # prompt (eval "$(starship init zsh)")
    zoxide          # navigation (eval "$(zoxide init zsh)", alias cd=z)
    atuin           # history search (eval "$(atuin init zsh)")
    yazi            # file manager (y() wrapper)
    mise            # managed tool environment via shims PATH
    eza             # ls/ll/la/lt aliases
    bat             # cat alias
    fd              # ff/fg aliases
)

# Nice to have; absence does not break the shell.
RECOMMENDED_PKGS=(fzf uv fish)

# src (repo-relative) | dest (absolute). Directories are walked per-file.
SHELL_CONFIG_MAP=(
    "home/.zshrc|$HOME/.zshrc"
    "home/.XCompose|$HOME/.XCompose"
    "starship/.config/starship.toml|$HOME/.config/starship.toml"
    "fish/.config/fish|$HOME/.config/fish"
    "mise/.config/mise|$HOME/.config/mise"
    "atuin/.config/atuin|$HOME/.config/atuin"
)

ZSH_PLUGIN_FILES=(
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
)

pkg_installed() {
    pacman -Q "$1" &>/dev/null
}

missing_required_pkgs() {
    local p
    for p in "${REQUIRED_PKGS[@]}"; do
        pkg_installed "$p" || printf '%s\n' "$p"
    done
}

current_login_shell() {
    getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7
}

login_shell_is_zsh() {
    local cur
    cur="$(current_login_shell)"
    [ -n "$cur" ] && [ "$(basename "$cur")" = "zsh" ]
}

etc_shells_has_zsh() {
    local want have
    want="$(command -v zsh 2>/dev/null)" || return 1
    want="$(realpath -e "$want" 2>/dev/null)" || return 1
    while IFS= read -r have; do
        [ -z "$have" ] && continue
        case "$have" in '#'*) continue ;; esac
        [ "$(realpath -e "$have" 2>/dev/null)" = "$want" ] && return 0
    done < /etc/shells 2>/dev/null
    return 1
}

uv_env_sh_content() {
    cat <<'EOF'
#!/bin/sh
# add binaries to PATH if they aren't added yet
# affix colons on either side of $PATH to simplify matching
case ":${PATH}:" in
    *:"$HOME/.local/share/../bin":*)
        ;;
    *)
        # Prepending path in case a system-installed binary needs to be overridden
        export PATH="$HOME/.local/share/../bin:$PATH"
        ;;
esac
EOF
}

uv_env_fish_content() {
    cat <<'EOF'
if not contains "$HOME/.local/share/../bin" $PATH
    # Prepending path in case a system-installed binary needs to be overridden
    set -x PATH "$HOME/.local/share/../bin" $PATH
end
EOF
}

# write_file_if_changed <target> <content> [backup_root]
# Prints SKIP/CHANGED and only touches disk when content actually differs.
write_file_if_changed() {
    local target="$1" content="$2" backup_root="${3:-}" existing=""
    existing="$(cat "$target" 2>/dev/null || true)"
    if [ "$existing" = "$content" ]; then
        echo "[SKIP]     $target (already correct)"
        return 0
    fi

    if [ -n "$backup_root" ] && [ -f "$target" ]; then
        local backup_dir="$backup_root$(dirname "$target")"
        mkdir -p "$backup_dir"
        cp -a "$target" "$backup_dir/$target"
        echo "[BACKUP]   $target -> ${backup_dir}/$target"
    fi

    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$content" > "$target"
    echo "[CHANGED]  wrote $target"
}

ensure_local_bin_env() {
    local backup_root="${1:-}"
    mkdir -p "$HOME/.local/bin"

    if ! write_file_if_changed "$HOME/.local/bin/env" "$(uv_env_sh_content)" "$backup_root"; then
        return 1
    fi
    if ! write_file_if_changed "$HOME/.local/bin/env.fish" "$(uv_env_fish_content)" "$backup_root"; then
        return 1
    fi
}

# Installs the env bootstrap files only if missing/drifted. Never installs uv
# itself; uv's own installer remains the owner/updater of that binary.
repair_uv_env_files() {
    echo "==> Ensuring ~/.local/bin/env (+ env.fish) exists..."
    echo "    (Normally created by uv's standalone installer;"
    echo "     recreated verbatim from its template when missing.)"
    ensure_local_bin_env "${1:-}"
}

ensure_zsh_in_etc_shells() {
    local zsh_path
    zsh_path="$(command -v zsh 2>/dev/null)" || {
        echo "ERROR: zsh is not installed; cannot add it to /etc/shells." >&2
        return 1
    }

    if etc_shells_has_zsh; then
        echo "[SKIP]     $zsh_path already listed in /etc/shells"
        return 0
    fi

    if ! printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null; then
        echo "ERROR: failed appending $zsh_path to /etc/shells." >&2
        return 1
    fi
    echo "[CHANGED]  appended $zsh_path to /etc/shells"
}

ensure_login_shell_is_zsh() {
    local zsh_path cur
    zsh_path="$(command -v zsh 2>/dev/null)" || {
        echo "ERROR: zsh is not installed; cannot change login shell." >&2
        return 1
    }

    if login_shell_is_zsh; then
        echo "[SKIP]     login shell for $(id -un) is already zsh ($(current_login_shell))"
        return 0
    fi

    ensure_zsh_in_etc_shells || return 1

    cur="$(current_login_shell)"
    echo "[CHANGED]  changing login shell for $(id -un): ${cur:-<unset>} -> $zsh_path"
    if ! sudo chsh -s "$zsh_path" "$(id -un)"; then
        echo "ERROR: chsh failed. Set it manually with: chsh -s $zsh_path" >&2
        return 1
    fi

    echo
    echo "    ============================================================"
    echo "    Login shell changed to zsh."
    echo "    Log out and back in (or open a NEW terminal session) for"
    echo "    the change to take effect."
    echo "    ============================================================"
    echo
}

# Copies every repo shell config over its installed counterpart, but only when
# content differs. Backs up any overwritten file under backup_root.
reapply_shell_configs() {
    local repo="$1" backup_root="${2:-}"
    local entry src dest rel file target

    for entry in "${SHELL_CONFIG_MAP[@]}"; do
        src="$repo/${entry%%|*}"
        dest="${entry#*|}"

        if [ -f "$src" ]; then
            local content existing
            content="$(cat "$src")"
            existing="$(cat "$dest" 2>/dev/null || true)"
            if [ "$existing" = "$content" ]; then
                echo "[SKIP]     $dest (already matches repo)"
            else
                write_file_if_changed "$dest" "$content" "$backup_root"
            fi
        elif [ -d "$src" ]; then
            while IFS= read -r -d '' file; do
                rel="${file#"$src"/}"
                target="$dest/$rel"
                if cmp -s "$file" "$target"; then
                    echo "[SKIP]     $target (already matches repo)"
                    continue
                fi
                if [ -n "$backup_root" ] && [ -f "$target" ]; then
                    mkdir -p "$backup_root$(dirname "$target")"
                    cp -a "$target" "$backup_root$target"
                    echo "[BACKUP]   $target -> ${backup_root}$target"
                fi
                mkdir -p "$(dirname "$target")"
                cp -a "$file" "$target"
                echo "[CHANGED]  installed $target"
            done < <(find "$src" -type f -print0)
        else
            echo "[MISSING]  $src not found in repo; skipped"
        fi
    done
}
