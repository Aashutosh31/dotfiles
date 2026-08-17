-- Personal input overrides restored from pre-Quattro setup.

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:ralt",

    repeat_rate = 50,
    repeat_delay = 300,

    numlock_by_default = true,

    sensitivity = 0.5,
    accel_profile = "adaptive",
    force_no_accel = false,

    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.8,
      disable_while_typing = true,
      drag_lock = true,
    },
  },
})

o.window("(Alacritty|kitty|foot)", {
  scroll_touchpad = 1.5,
})

o.window("com.mitchellh.ghostty", {
  scroll_touchpad = 0.2,
})