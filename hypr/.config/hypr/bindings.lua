-- Personal bindings restored from pre-Quattro setup.

local custom = {
  "SUPER + RETURN",
  "SUPER + ALT + RETURN",

  "SUPER + SHIFT + RETURN",
  "SUPER + SHIFT + F",
  "SUPER + SHIFT + ALT + F",
  "SUPER + SHIFT + B",
  "SUPER + SHIFT + ALT + B",
  "SUPER + SHIFT + M",
  "SUPER + SHIFT + ALT + M",
  "SUPER + SHIFT + C",
  "SUPER + SHIFT + D",
  "SUPER + SHIFT + G",
  "SUPER + SHIFT + O",
  "SUPER + SHIFT + W",
  "SUPER + SHIFT + SLASH",

  "SUPER + SHIFT + A",
  "SUPER + SHIFT + ALT + A",
  "SUPER + SHIFT + N",
  "SUPER + SHIFT + E",
  "SUPER + SHIFT + Y",
  "SUPER + SHIFT + ALT + G",
  "SUPER + SHIFT + CTRL + G",
  "SUPER + SHIFT + P",
  "SUPER + SHIFT + X",
  "SUPER + SHIFT + ALT + X",

  "SUPER + CTRL + SHIFT + S",
  "SUPER + H",
}

for _, key in ipairs(custom) do
  hl.unbind(key)
end

o.bind("SUPER + RETURN",
  "Terminal",
  'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"')

o.bind("SUPER + ALT + RETURN",
  "Tmux",
  'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" bash -c "tmux attach || tmux new -s Work"')

o.bind("SUPER + SHIFT + RETURN",
  "Browser",
  "omarchy-launch-browser")

o.bind("SUPER + SHIFT + F",
  "File manager",
  "uwsm-app -- nautilus --new-window")

o.bind("SUPER + SHIFT + ALT + F",
  "File manager (cwd)",
  'uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"')

o.bind("SUPER + SHIFT + B",
  "Browser",
  "omarchy-launch-browser")

o.bind("SUPER + SHIFT + ALT + B",
  "Browser (private)",
  "omarchy-launch-browser --private")

o.bind("SUPER + SHIFT + M",
  "Music",
  "omarchy-launch-or-focus spotify")

o.bind("SUPER + SHIFT + ALT + M",
  "Music TUI",
  "omarchy-launch-or-focus-tui cliamp")

o.bind("SUPER + SHIFT + C",
  "Editor",
  "omarchy-launch-editor")

o.bind("SUPER + SHIFT + D",
  "Docker",
  "omarchy-launch-tui lazydocker")

o.bind("SUPER + SHIFT + G",
  "Signal",
  'omarchy-launch-or-focus ^signal$ "uwsm-app -- signal-desktop"')

o.bind("SUPER + SHIFT + O",
  "Obsidian",
  'omarchy-launch-or-focus ^obsidian$ "uwsm-app -- obsidian"')

o.bind("SUPER + SHIFT + W",
  "Typora",
  "uwsm-app -- typora --enable-wayland-ime")

o.bind("SUPER + SHIFT + SLASH",
  "Passwords",
  "uwsm-app -- 1password")

o.bind("SUPER + SHIFT + A",
  "ChatGPT",
  'omarchy-launch-webapp "https://chatgpt.com"')

o.bind("SUPER + SHIFT + ALT + A",
  "Grok",
  'omarchy-launch-webapp "https://grok.com"')

o.bind("SUPER + SHIFT + N",
  "Calendar",
  'omarchy-launch-webapp "https://app.hey.com/calendar/weeks/"')

o.bind("SUPER + SHIFT + E",
  "Email",
  'omarchy-launch-webapp "https://app.hey.com"')

o.bind("SUPER + SHIFT + Y",
  "YouTube",
  'omarchy-launch-webapp "https://youtube.com/"')

o.bind("SUPER + SHIFT + ALT + G",
  "WhatsApp",
  'omarchy-launch-or-focus-webapp WhatsApp "https://web.whatsapp.com/"')

o.bind("SUPER + SHIFT + CTRL + G",
  "Google Messages",
  'omarchy-launch-or-focus-webapp "Google Messages" "https://messages.google.com/web/conversations"')

o.bind("SUPER + SHIFT + P",
  "Google Photos",
  'omarchy-launch-or-focus-webapp "Google Photos" "https://photos.google.com/"')

o.bind("SUPER + SHIFT + X",
  "X",
  'omarchy-launch-webapp "https://x.com/"')

o.bind("SUPER + SHIFT + ALT + X",
  "X Post",
  'omarchy-launch-webapp "https://x.com/compose/post"')

o.bind("SUPER + H",
  nil,
  "voxtype record toggle")

-- Snapshot every config this repo owns, plus a bootable root snapshot.
-- Runs in a terminal on purpose: snapper needs a TTY for the sudo prompt.
-- Restore with `checkpoint undo` (or Personal → Undo last checkpoint).
o.bind("SUPER + CTRL + SHIFT + S",
  "Checkpoint",
  "omarchy-launch-tui checkpoint --pause")

-- Cyberdeck: hide the desktop furniture and apply the scanline shader.
-- On-demand only — see scripts/cyberdeck for what it changes and restores.
o.bind("SUPER + CTRL + SHIFT + D",
  "Cyberdeck mode",
  "cyberdeck toggle")

-- HUD scratchpads. The window rule pins these terminals to their own special
-- workspace, so the spawn works without relying on process tracking (Omarchy
-- turns off misc.initial_workspace_tracking) and a HUD that is already running
-- comes back instantly instead of being launched twice.
--
-- Omarchy floats every org.omarchy.* TUI and sizes it to 875x600 through the
-- `floating-window` tag. That is the right default for a terminal popup and the
-- wrong shape for a btop HUD, so the tag is dropped here and the size set
-- explicitly; float and center are then restated rather than inherited.
o.window("^(org\\.omarchy\\.btop)$", {
  tag = "-floating-window",
  float = true,
  center = true,
  size = { 1180, 640 },
  opacity = "0.94 0.9",
  workspace = "special:sysmon",
})

o.window("^(org\\.omarchy\\.yazi)$", {
  tag = "-floating-window",
  float = true,
  center = true,
  size = { 1000, 700 },
  opacity = "0.94 0.9",
  workspace = "special:files",
})

-- Open the HUD, and seed it on first use (or after its app was quit). The
-- workspace persists, so an already-running btop costs one toggle, nothing else.
local function hud_toggle(name, launch)
  local ws = "special:" .. name

  return function()
    local active = hl.get_active_special_workspace()
    local opening = not (active and active.name == ws)

    hl.dispatch(hl.dsp.workspace.toggle_special(name))

    if opening then
      local windows = hl.get_workspace_windows(ws)
      if not windows or #windows == 0 then
        hl.exec_cmd(launch)
      end
    end
  end
end

o.bind("SUPER + CTRL + G",
  "System monitor HUD",
  hud_toggle("sysmon", "omarchy-launch-tui btop"))

o.bind("SUPER + CTRL + Y",
  "File manager HUD",
  hud_toggle("files", "omarchy-launch-tui yazi"))

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end
