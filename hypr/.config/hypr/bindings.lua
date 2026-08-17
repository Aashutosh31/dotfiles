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
