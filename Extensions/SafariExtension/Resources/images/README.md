# Safari extension icons

Production ship needs five PNGs in this folder. Add them and re-declare in
`manifest.json` under both `"icons"` (preferences/dialog) and
`"action.default_icon"` (toolbar):

```
icon-48.png       ─┐
icon-96.png        │   "icons":  preferences listing, install prompt
icon-128.png       │
icon-256.png       │
icon-512.png      ─┘

toolbar-icon-16.png  ─┐
toolbar-icon-32.png   │   "action.default_icon":  Safari toolbar
toolbar-icon-64.png  ─┘
```

Style: single-color, edge-to-edge, matching the host app's Orbit mark. Apple
recommends black-on-transparent for toolbar icons so Safari can re-tint per
toolbar background.

We ship without icons today so the extension builds against a clean repo —
Safari falls back to a generic puzzle-piece glyph in the toolbar.
