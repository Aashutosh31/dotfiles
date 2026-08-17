-- Personal look'n'feel
-- Restored from the pre-Quattro Omarchy configuration.

local easeOut = {
  type = "bezier",
  points = {
    { 0.25, 0.1 },
    { 0.25, 1.0 },
  },
}

local smooth = {
  type = "bezier",
  points = {
    { 0.4, 0.0 },
    { 0.2, 1.0 },
  },
}

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 6,
    border_size = 2,
  },

  decoration = {
    rounding = 10,

    active_opacity = 1.0,
    inactive_opacity = 0.82,
    fullscreen_opacity = 1.0,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      xray = true,
    },

    dim_inactive = true,
    dim_strength = 0.12,
  },

  animations = {
    enabled = true,
  },
})

hl.curve("easeOut", easeOut)
hl.curve("smooth", smooth)

hl.animation({
  leaf = "windows",
  enabled = true,
  speed = 5,
  bezier = "smooth",
  style = "slide",
})

hl.animation({
  leaf = "windowsOut",
  enabled = true,
  speed = 5,
  bezier = "smooth",
  style = "slide",
})

hl.animation({
  leaf = "border",
  enabled = true,
  speed = 10,
  bezier = "default",
})

hl.animation({
  leaf = "fade",
  enabled = true,
  speed = 5,
  bezier = "easeOut",
})

hl.animation({
  leaf = "workspaces",
  enabled = true,
  speed = 6,
  bezier = "smooth",
  style = "slidefade",
})