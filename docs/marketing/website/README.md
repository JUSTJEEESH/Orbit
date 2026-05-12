# Orbit marketing website

Static HTML + CSS + one tiny JS file. Designed to deploy to Netlify
as-is — no build step.

## Files

| File           | What it is                                                                |
|----------------|---------------------------------------------------------------------------|
| `index.html`   | Homepage (hero, features, privacy, integrations, end-CTA)                 |
| `privacy.html` | Privacy Policy (Apple-Review ready)                                        |
| `terms.html`   | Terms of Use                                                              |
| `support.html` | Support / FAQ                                                              |
| `404.html`     | Custom not-found page                                                     |
| `styles.css`   | Design tokens, typography, layout — mirrors the iOS app's visual system   |
| `script.js`    | Tiny scroll-reveal + live copyright year (~600 bytes, no deps)            |
| `favicon.svg`  | Vector favicon (dark background + theme-accent logo)                      |
| `sprites.svg`  | Shared SVG sprite (currently unused; inline symbols used per-page)        |
| `netlify.toml` | Pretty URLs, security headers, cache rules                                 |

## Deploy

### Option 1 — Netlify drop (fastest)

1. Compress this `website/` folder into a `.zip`.
2. Drag-and-drop onto <https://app.netlify.com/drop>.
3. Rename the site to `orbitbrain2` in **Site settings → General → Site name**.

Done. Subsequent updates: just drop a new zip with the same site selected.

### Option 2 — Netlify connected to Git (recommended for ongoing work)

1. Push the repo (the `claude/ios-app-architecture-p5jNu` branch is fine).
2. In Netlify dashboard → **Add new site → Import from Git**.
3. Pick this repo.
4. **Base directory**: `docs/marketing/website`
5. **Publish directory**: `docs/marketing/website` (same — there's no build).
6. **Build command**: leave blank.
7. Deploy.

The `netlify.toml` in this folder takes care of pretty URLs and headers.

## URL routes

After deploy:

- `/`           → `index.html`
- `/privacy`    → `privacy.html`
- `/terms`      → `terms.html`
- `/support`    → `support.html`
- anything else → `404.html`

These match the URLs hardcoded into the iOS app's Settings → About
section, so **don't rename these files without updating
`SettingsView.swift`** (and the rest of the `docs/marketing/` drafts).

## Placeholders to fill in before launch

Search each `.html` file for `{{` and replace:

| Placeholder                              | Where it appears              |
|------------------------------------------|-------------------------------|
| `{{ launch date }}`                      | privacy.html, terms.html      |
| `{{ your legal name or company }}`       | privacy.html, terms.html      |
| `{{ your jurisdiction }}`                | terms.html                    |
| `idXXXXXXXXX` in App Store URLs          | index.html (hero + end CTA)   |

The current copyright year is set live by JS — no manual updates each
year.

## Email setup

The pages all use `support@orbitbrain2.netlify.app` as the contact
address. **Netlify doesn't host email**, so before launch you need:

- **Easiest path**: buy a custom domain → point it at this Netlify
  site → set up free email forwarding via your domain registrar
  (Cloudflare Email Routing is free) → `support@yourdomain.app` →
  forwarded to your personal Gmail.
- **Alternative**: search/replace `support@orbitbrain2.netlify.app`
  in all `.html` files with your personal email. Less professional but
  works for Apple Review.

## Open Graph image

The pages reference `/og-image.png` for link previews on Twitter,
Slack, iMessage, etc. You'll want to add a **1200 × 630** PNG at the
site root. Suggested composition mirrors the in-app share cards:

- Solid background in the Orbit accent (cool blue `#2D5BFF`).
- Logo + wordmark, oversized, left-aligned.
- Tagline in serif: *"Memories find their orbit."*
- App-icon mockup small in the bottom-right corner.

If you skip this, the browser falls back to a stock preview — not
broken, just plain.

## App icon for `apple-touch-icon`

Add `/apple-touch-icon.png` at **180 × 180** (the iOS Safari "Add to
Home Screen" icon). Same accent-on-dark composition as the favicon
but raster.

## Design system

Everything visual lives in `styles.css` and uses CSS custom
properties. To change the accent color across the entire site, edit
two values:

```css
:root {
  --accent: #2D5BFF;            /* light-mode accent */
}
@media (prefers-color-scheme: dark) {
  :root {
    --accent: #5A82FF;          /* dark-mode accent */
  }
}
```

To change the wordmark color in the favicon, edit `favicon.svg`
directly (it's an inline path with `fill="#5A82FF"`).
