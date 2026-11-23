<div align="center">

```
 █████╗  █████╗ ███████╗██╗  ██╗██╗   ██╗████████╗ ██████╗ ███████╗██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔═══██╗██╔════╝██║  ██║
███████║███████║███████╗███████║██║   ██║   ██║   ██║   ██║███████╗███████║
██╔══██║██╔══██║╚════██║██╔══██║██║   ██║   ██║   ██║   ██║╚════██║██╔══██║
██║  ██║██║  ██║███████║██║  ██║╚██████╔╝   ██║   ╚██████╔╝███████║██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝
```

**Arch Linux · Omarchy · Hyprland — my daily driver, versioned.**

[![Arch Linux](https://img.shields.io/badge/OS-Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/WM-Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=white)](https://hyprland.org)
[![Omarchy](https://img.shields.io/badge/Base-Omarchy-00C7B7?style=for-the-badge)](https://github.com/basecamp/omarchy)
[![Shell](https://img.shields.io/badge/Shell-Zsh-89E051?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.zsh.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

<br>

### ▶️ Live Demo

[Demo Video](https://youtu.be/pNU84d3qIt0)

📝 **Write-up:** [From a fresh Arch install to a fully configured environment in one command](https://dev.to/aashutosh_bairagi_31/from-a-fresh-arch-install-to-a-fully-configured-development-environment-in-one-command-4cg5)

</div>

---

## `$ cat table_of_contents.txt`

- [Screenshots](#-screenshots)
- [Features](#-features)
- [Included Configurations](#-included-configurations)
- [Personal Omarchy Plugins](#-personal-omarchy-plugins)
- [Installation](#-installation)
- [Updating an Existing Installation](#-updating-an-existing-installation)
- [🩺 Diagnose & Repair](#-diagnose--repair)
- [Zsh Is Required](#%EF%B8%8F-zsh-is-required)
- [About `~/.local/bin/env`](#about-localbinenv)
- [What `install.sh` Actually Does](#-what-installsh-actually-does)
- [What `bootstrap.sh` Actually Does](#-what-bootstrapsh-actually-does)
- [Repository Structure](#-repository-structure)
- [Requirements](#-requirements)
- [Backups & Rollback](#-backups--rollback)
- [Wallpaper Credits](#️-wallpaper-credits)
- [License](#-license)

---

## 📸 Screenshots

<div align="center">

<a href="screenshots/">
  <img src="screenshots/desktop.png" alt="Desktop" width="100%" />
</a>
<p><em>Hero shot: Hyprland + Omarchy shell + wallhaven</em></p>

<table>
  <tr>
    <td width="50%">
      <a href="screenshots/">
        <img src="screenshots/terminal.png" alt="Terminal" width="100%" />
      </a>
    </td>
    <td width="50%">
      <a href="screenshots/">
        <img src="screenshots/vscode.png" alt="VS Code" width="100%" />
      </a>
    </td>
  </tr>
  <tr>
    <td><em>Ghostty + Fastfetch + Starship</em></td>
    <td><em>Editor workflow in VS Code</em></td>
  </tr>
</table>

<table>
  <tr>
    <td width="33%">
      <a href="screenshots/">
        <img src="screenshots/neovim.png" alt="Neovim" width="100%" />
      </a>
    </td>
    <td width="33%">
      <a href="screenshots/">
        <img src="screenshots/yazi.png" alt="Yazi" width="100%" />
      </a>
    </td>
    <td width="33%">
      <a href="screenshots/">
        <img src="screenshots/screensaver.png" alt="Screensaver" width="100%" />
      </a>
    </td>
  </tr>
  <tr>
    <td><em>LazyVim</em></td>
    <td><em>Yazi file manager</em></td>
    <td><em>Idle screensaver</em></td>
  </tr>
</table>

</div>

## ✨ Features

|                             |                                              |
| --------------------------- | -------------------------------------------- |
| 🖥️ **WM**                   | Hyprland on Omarchy (Quickshell-based shell) |
| 🎨 **Theme**                | wallhaven, applied system-wide via Aether    |
| ⚡ **System Info**          | Fastfetch                                    |
| ⭐ **Prompt**               | Starship                                     |
| 📝 **Editors**              | Neovim (LazyVim) & VS Code                   |
| 📂 **File Manager**         | Yazi                                         |
| 🐚 **Shell**                | Zsh (fish in foot)                           |
| 👻 **Terminal**             | Ghostty / Alacritty / Kitty / Foot           |
| 📊 **Monitor**              | Btop                                         |
| 🚀 **Bar / Launcher / OSD** | Omarchy shell (Quickshell)                   |
| 🖼️ **Wallpapers**           | Curated collection included                  |

---

## 📦 Included Configurations

```
alacritty · atuin · btop · fastfetch · fish · foot · ghostty · hyprland
kitty · lazydocker · lazygit · mise · mpv · neovim · omarchy · starship
tmux · VS Code · yazi · zellij · zsh
```

## 🧩 Personal Omarchy Plugins

This repository includes personal extensions created for **Aashutosh31's own
Omarchy setup**. They are not part of the original Omarchy distribution.

### `aashutosh31.bar` — Astra Islands

The personal bar clone keeps Omarchy's bar engine and interactions, with a
Wallhaven-tuned three-island glass aesthetic: menu/workspace tabs on the left,
an editorial clock and media in the center, and system controls on the right.
The separate backplates leave wallpaper visible between each group.

The layout uses two companion widgets:

- `aashutosh31.astra-clock` — a typographic clock with the Omarchy calendar
  popup and format cycling.
- `aashutosh31.astra-workspaces` — compact animated workspace tabs showing
  focused and occupied workspaces.

Sources:

```text
omarchy/.config/omarchy/plugins/aashutosh31.bar/
omarchy/.config/omarchy/plugins/aashutosh31.astra-clock/
omarchy/.config/omarchy/plugins/aashutosh31.astra-workspaces/
omarchy/.config/omarchy/shell.json
```

### `aashutosh31.cpu` — CPU bar widget

Created and maintained by **Aashutosh31**. It adds a small live CPU indicator
to the bar. Clicking it opens `btop`; if btop is already running, it focuses
the existing window instead of starting another one.

Source:

```text
omarchy/.config/omarchy/plugins/aashutosh31.cpu/
```

The plugin is intentionally namespaced `aashutosh31.cpu` so it is clearly
separate from first-party `omarchy.*` plugins. Its manifest also records
`aashutosh31` as the author.

### Personal menu extensions

The **Personal** menu in this setup is also custom work from this repository;
it is not part of a fresh Omarchy installation. It contains:

- **Cyberdeck mode** — temporarily hides the bar, removes window gaps and
  applies the lightweight cyberdeck screen effect. Choosing it again restores
  the normal desktop.
- **Checkpoint now** — saves the current Omarchy configuration before trying
  a risky change.
- **Checkpoint + all of /home** — makes the larger, extra-cautious backup that
  also covers the home folder.
- **Undo last checkpoint** — returns the configuration to the last saved
  checkpoint if a change went wrong.

These entries are defined in:

```text
omarchy/.config/omarchy/extensions/omarchy-menu.jsonc
```

They are personal convenience actions layered on top of Omarchy, while the
underlying Omarchy files remain untouched.

### Dictation

Omarchy's default dictation backend is Superwhisper (`superwhisper-bin`), and
this setup uses it. The older Voxtype installation was removed: its user
service, package entry, config directory, and `SUPER+H` bind are gone, so only
one recorder starts at login.

`SUPER+H` is kept as a personal dictation key and now routes through
`omarchy-dictation toggle` instead of calling Voxtype directly.

The bar shows Superwhisper's own panel widget (`superwhisper.panel`) in the
right section. Its icon is the live dictation state — a red dot appears while
recording — and left-clicking opens the Superwhisper panel. It was moved out of
the tray drawer, where it was hidden until the drawer was opened. The older
personal `Dictation` indicator, which called the removed
`omarchy-voxtype-status`, has been retired.

### `aashutosh31.media` — personal Media Deck

The personal Media Deck is placed in the centered bar group beside the clock.
When Spotify, YouTube Music, or another MPRIS-compatible player is
playing, it shows a compact track pill with title and artist. The
pill tooltip includes the source player; left-click opens the popup, right-click
toggles play/pause, middle-click skips forward, and the scroll wheel adjusts
player volume when supported. The popup includes title, artist,
album, previous, play/pause, next, shuffle, repeat controls, available-player
switching, elapsed/total time, a clickable seek bar, and a player-volume slider
with mute. Unsupported MPRIS capabilities are hidden or disabled. It uses
Quickshell's standard MPRIS interface but has a personal presentation and
interaction design.

MPRIS title, artist, and album metadata is rendered as plain text, not HTML, and
displayed fields are length-capped. The widget does not load cover art: even
local MPRIS paths can refer to blocking special files, and checking before
opening would leave a race. It uses a music-note placeholder instead, so no
player-controlled URL or filesystem path reaches Qt Quick's image loader.

Chrome/Chromium YouTube Music and native MPRIS players expose the full
timeline, so their progress and seeking work. Firefox's current YouTube Music
MPRIS bridge exposes playback controls but reports no usable duration and a
position of zero; the Media Deck therefore cannot provide a truthful live
progress bar or seeking for that Firefox source. When Chrome and Firefox are
both playing, the widget prefers the source with real timeline data.

Source:

```text
omarchy/.config/omarchy/plugins/aashutosh31.media/
```

Published as a standalone plugin, MIT licensed:

```text
https://github.com/Aashutosh31/omarchy-media-deck
```

Install it on any Omarchy machine with:

```bash
omarchy plugin add https://github.com/Aashutosh31/omarchy-media-deck.git --enable
```

---

## 📥 Installation

### Option A — One-shot bootstrap (fresh machine)

```bash
curl -fsSL https://raw.githubusercontent.com/Aashutosh31/dotfiles/main/bootstrap.sh | bash
```

Handles everything: installs `git`/`yay` if missing, clones the repo, and runs the installer.

### Option B — Manual (already have the repo cloned, or want to review first)

```bash
git clone https://github.com/Aashutosh31/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

After installation, if Hyprland is running, reload the config to apply changes:

```bash
hyprctl reload
```

Then **open a new terminal** — the installer makes sure zsh is your login shell, and a shell change only applies to new login sessions.

---

## 🔁 Updating an Existing Installation

`install.sh` is safe to re-run at any time — that *is* the update mechanism:

```bash
cd ~/dotfiles
git pull
./install.sh
```

- Every file it overwrites is backed up first to `~/.dotfiles-backup/<timestamp>/`.
- It never deletes your config directories and never removes files that only exist on your system.
- It does **not** perform a system upgrade (no `pacman -Syu`) — on Omarchy, upgrades belong to `omarchy update`, which the installer never bypasses. It only installs packages from `packages/` that are missing.
- If something in your shell environment is still off afterwards, see [Diagnose & Repair](#-diagnose--repair) below.

---

## 🩺 Diagnose & Repair

Two companion scripts let you fix problems without reinstalling everything.

### `doctor.sh` — read-only health check

```bash
./doctor.sh
```

Checks, without touching anything:

| Check                                             | Severity |
| ------------------------------------------------- | -------- |
| Required packages installed (`zsh`, `starship`, `zoxide`, `atuin`, `yazi`, `mise`, plugins, …) | FAIL if missing |
| Commands resolvable on `$PATH`                     | FAIL if missing |
| `/bin/zsh` + `/usr/bin/zsh` exist, zsh listed in `/etc/shells` | FAIL if missing |
| Login shell is zsh                                 | FAIL otherwise |
| `~/.local/bin/env` + `env.fish` present            | FAIL if missing |
| zsh-autosuggestions / zsh-syntax-highlighting plugin files | FAIL if missing |
| Installed shell configs match the repo             | WARN on drift |
| Broken symlinks under `~/.config`                  | WARN |
| `checkpoint` on `$PATH`, checkpoint count, snapper + Limine boot sync | WARN |

Exit code is non-zero when any required component is missing, so you can use it in scripts or CI.

### `repair.sh` — fix an existing installation

```bash
./repair.sh
```

Safe and idempotent — run it as many times as you like; unchanged state prints `[SKIP]`. It:

1. Installs **only** required packages that are actually missing.
2. Ensures zsh is installed and listed in `/etc/shells`.
3. Sets your login shell to zsh — **only if it isn't already** (never repeats `chsh`), printing a clear message and reminding you to start a new session.
4. Recreates `~/.local/bin/env` / `env.fish` when they are missing (see below).
5. Re-applies only the shell-related configs (`.zshrc`, `.XCompose`, starship, fish, mise, atuin) — each backed up before being overwritten.

It never runs a system upgrade, never deletes home/config data, and exits non-zero if anything could not be fixed.

### `checkpoint` — one-command snapshot & undo

```bash
checkpoint                 # configs + manifest + git tag (+ root snapshot on a TTY)
checkpoint --full          # also a read-only btrfs snapshot of /home
checkpoint list
checkpoint verify
checkpoint undo [<ts>]
```

Or press <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd>, or use
**Personal → Checkpoint now** / **Undo last checkpoint** in the Omarchy menu.

Three layers, because one is not enough:

| Layer | Covers | Notes |
| --- | --- | --- |
| Configs | the ~29 MB this repo owns (`hypr`, `omarchy`, `ghostty`, `zellij`, `tmux`, `btop`, `nvim`, `yazi`, `fish`, `starship.toml`, `~/.local/bin/checkpoint`, toggle flags) | `~/.dotfiles-backup/<ts>/` plus a `checkpoint/<ts>` git tag. No root needed. |
| System | packages, `/usr`, system config | `omarchy snapshot create` → snapper → **selectable in the Limine boot menu**. Needs a TTY for the sudo prompt. |
| `/home` | everything in your home directory | `--full` only. Read-only btrfs snapshot in `/.snapshots-home/`; CoW, so effectively free. |

`undo` restores the config layer with `rsync --delete` (files added after the
checkpoint are removed too), reloads Hyprland, restarts the shell, and fails
loudly if `hyprctl configerrors` is non-empty. It first saves the current state
as `<ts>-pre-undo`, so an undo can itself be undone.

Note: snapper is configured for `SUBVOLUME="/"` only, so a root rollback does
**not** touch `~/.config`. That is the gap the config layer fills.

### `cyberdeck` — one toggle for the HUD look

```bash
cyberdeck            # toggle
cyberdeck on|off|status
```

On: bar hidden, gaps and borders 0, inactive dimming off, notifications in DND,
and `~/.config/hypr/shaders/cyberdeck.glsl` applied (scanlines + vignette, one
texture fetch, no `time` uniform). Off: `hyprctl reload` restores gaps, borders
and dimming from the config, and the bar/DND flags return to whatever they were.

| Key | Does |
| --- | --- |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> | Cyberdeck on/off |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>G</kbd> | btop HUD (`special:sysmon`) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>Y</kbd> | yazi HUD (`special:files`) |

The two HUDs are floating scratchpads on their own special workspaces: nothing
runs until the key is pressed, an already-running HUD is toggled rather than
relaunched, and closing its app means the next press starts it again.

The shader is self-contained. The 138 `~/.config/hypr/shaders/*.glsl` symlinks
point at `/usr/share/aether/shaders/`, which is not installed on this machine,
so Aether's shader picker has nothing to offer here.

---

## 🐚 Zsh Is Required

This setup **requires Zsh**. The shell environment depends on zsh-specific features:

- zsh options & completion (`setopt`, `autoload -Uz compinit`)
- zoxide integration (`z`, `cd=z`)
- atuin history integration (`eval "$(atuin init zsh)"`)
- zsh-autosuggestions & zsh-syntax-highlighting
- Starship prompt
- all existing aliases/functions in [.zshrc](home/.zshrc)

`install.sh` and `repair.sh` both ensure: zsh installed → `/bin/zsh` present and listed in `/etc/shells` → login shell set to `/bin/zsh` (only when needed). After the change you must **start a new login session/terminal** for it to take effect. Don't try to `source ~/.zshrc` from Bash — it uses zsh-only builtins and will error.

---

## About `~/.local/bin/env`

The last line of `.zshrc` sources `~/.local/share/../bin/env` (= `~/.local/bin/env`). That file is created by **uv's standalone installer** (`curl -LsSf https://astral.sh/uv/install.sh | sh`), not by mise, Omarchy, pacman, or this repo. On a fresh machine where uv was never installed standalone, the file doesn't exist and every zsh startup ends with:

```
/home/<you>/.local/share/../bin/env: No such file or directory
```

`install.sh` and `repair.sh` recreate this file — byte-for-byte identical to uv's template — whenever it is missing, so the shell always starts cleanly even before uv itself is installed.

---

## 🔍 What `install.sh` Actually Does

<details>
<summary><strong>Click to expand the step-by-step breakdown</strong></summary>

1. **Resolves the repo path** — works regardless of where you run it from (`$REPO` = script's own directory).
2. **Installs missing official packages** — ensures everything in [`packages/pacman.txt`](packages/pacman.txt) is present, using Omarchy's `omarchy-pkg-add` helper when available (falling back to `pacman -S --needed`). This **does not perform a full system upgrade** — on Omarchy, system upgrades belong to `omarchy update`, which the installer never bypasses.
3. **Installs AUR packages** — if `yay` is present, installs everything in [`packages/aur.txt`](packages/aur.txt) non-interactively (`--answerclean None --answerdiff None`). Skips gracefully if `yay` isn't found.
4. **Creates a timestamped backup** at `~/.dotfiles-backup/<YYYY><MM><DD>-<HHMMSS>/` — see [Backups & Rollback](#-backups--rollback) below.
5. **Backs up and replaces each config** — for every tool in the list (`alacritty`, `atuin`, `btop`, `fastfetch`, `fish`, `foot`, `ghostty`, `hypr`, `kitty`, `lazydocker`, `lazygit`, `mise`, `mpv`, `nvim`, `omarchy`, `tmux`, `yazi`, `zellij`):
   - if a matching config exists in this repo, each file in your current `~/.config/<tool>` is backed up individually, then replaced in-place (safe to run while a desktop session is live — the directory is never deleted).
6. **Installs starship** at `~/.config/starship.toml`, the **wallhaven theme background** into `~/.config/omarchy/themes/wallhaven/`, and the custom **About screen launcher** to `~/.local/bin/omarchy-launch-about`.
7. **Backs up and replaces dotfiles** — `~/.zshrc` and `~/.XCompose` get the same backup-then-overwrite treatment.
8. **Sets up the shell environment (Stage 4)** — makes sure copying `.zshrc` actually results in a *usable* shell:
   - adds zsh to `/etc/shells` if missing,
   - sets your login shell to zsh **only if it isn't already** (never re-runs `chsh` unnecessarily; prints a clear message when it changes and reminds you that a new login session is needed),
   - recreates `~/.local/bin/env` + `env.fish` if they're missing (uv-installer template — see [About `~/.local/bin/env`](#about-localbinenv)),
   - verifies every command `.zshrc` depends on resolves, warning about any that don't.
9. **Prints the backup location** so you always know exactly where your previous setup went.

**Nothing is deleted without a backup first.** Every overwrite is preceded by a copy (`cp -a`) into the timestamped backup folder. Configs are installed via per-file in-place replacement so a running desktop session never sees a missing or partially-written config directory.

</details>

---

## 🥾 What `bootstrap.sh` Actually Does

<details>
<summary><strong>Click to expand</strong></summary>

Bootstrap is for a **brand-new machine** that doesn't have this repo (or possibly `git`/`yay`) yet:

1. **Verifies you're on Arch** — checks for `pacman`, exits cleanly otherwise (no Arch, no dice).
2. **Installs Git** if missing.
3. **Installs `yay`** if missing — clones and builds it from the AUR via `makepkg -si`.
4. **Clones or updates the repo** — clones fresh to `~/dotfiles` if it doesn't exist, or `git pull`s if it does.
5. **Makes scripts executable** — `install.sh` and everything in `scripts/`.
6. **Hands off to `install.sh`** to do the actual config installation described above.

In short: `bootstrap.sh` gets a bare Arch install to the point where `install.sh` can run — then runs it.

</details>

---

## 📂 Repository Structure

```text
.
├── alacritty/
├── atuin/
├── btop/
├── doctor.sh       # read-only installation health check
├── fastfetch/
├── fish/
├── foot/
├── ghostty/
├── home/          # ~/.zshrc, ~/.XCompose
├── hypr/          # Hyprland Lua config (Quattro)
├── kitty/
├── lazydocker/
├── lazygit/
├── mise/
├── mpv/
├── nvim/
├── repair.sh      # safe, idempotent in-place repair
├── vscode/
├── omarchy/       # shell, bar plugin, theme, hooks, theme.name
├── bootstrap.sh   # one-shot installer for fresh machines
├── packages/       # pacman.txt, aur.txt
├── scripts/       # checkpoint, omarchy-launch-about, lib/shell-env.sh
├── starship/
├── tmux/
├── wallpapers/
├── yazi/
└── zellij/
```

---

## 🛠 Requirements

- Arch Linux
- [Omarchy](https://github.com/basecamp/omarchy)
- **Zsh** (installed and set as login shell automatically by `install.sh` / `repair.sh` — required for this setup to function)
- `yay` (auto-installed by `bootstrap.sh` if missing)
- Git

---

## 🔄 Backups & Rollback

Every run of `install.sh` creates a fresh timestamped snapshot before touching anything:

```
~/.dotfiles-backup/20260701-143022/
```

To roll back a specific config manually:

```bash
cp -a ~/.dotfiles-backup/<timestamp>/.config/<tool> ~/.config/
```

## 📜 License

MIT License

<div align="center">

`built in the terminal, for the terminal`

</div>
