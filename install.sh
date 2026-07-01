backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

echo "==> Creating backup..."
mkdir -p "$backup_dir"

backup() {
    if [ -e "$1" ]; then
        mkdir -p "$backup_dir$(dirname "$1")"
        cp -a "$1" "$backup_dir$1"
    fi
}

restore_config() {
    local name="$1"

    backup "$HOME/.config/$name"

    rm -rf "$HOME/.config/$name"
    mkdir -p "$HOME/.config"

    cp -a "$REPO/$name/.config/$name" "$HOME/.config/"
}

for cfg in \
alacritty atuin btop fastfetch ghostty hypr kitty lazydocker lazygit \
mise mpv nvim starship swayosd tmux voxtype walker waybar wiremix \
yazi zellij
do
    restore_config "$cfg"
done

backup "$HOME/.zshrc"
backup "$HOME/.XCompose"

cp -f "$REPO/home/.zshrc" ~/
cp -f "$REPO/home/.XCompose" ~/