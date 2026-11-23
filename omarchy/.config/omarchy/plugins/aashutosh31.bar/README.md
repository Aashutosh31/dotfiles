# Astra Islands bar

This personal `aashutosh31.bar` clone keeps Omarchy's bar engine and
interactions while giving the horizontal bar a three-island glass treatment
tuned for the Wallhaven palette:

- **Left island:** Omarchy menu and Astra workspace tabs.
- **Center island:** indicators, Media Deck, Astra's editorial clock, world
  clock, and weather.
- **Right island:** system tray and system controls.

Separate translucent backplates leave wallpaper visible between the groups.
The centered Astra clock remains the anchor; the bar also keeps Omarchy's
transparent mode and vertical layout behavior.

The clock and workspace tabs are separate personal bar-widget plugins:

```text
../aashutosh31.astra-clock/
../aashutosh31.astra-workspaces/
```

`shell.json` is the source of truth for placement and clock formatting. The
bar itself stays a clone of `omarchy.bar`, so Omarchy owns the underlying
widget loading, drag/reorder behavior, gestures, and popup routing.
