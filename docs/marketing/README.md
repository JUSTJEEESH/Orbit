# Orbit launch docs

Drafts for everything outside the iOS binary that needs to exist
before App Store submission.

| File | What it is | Where it goes |
|------|------------|---------------|
| `app-store-listing.md` | App name, subtitle, keywords, description, what's new, categories, privacy nutrition answers | App Store Connect (manual entry) |
| `landing.md` | Marketing site homepage copy + SEO metadata | `orbitbrain2.netlify.app/` |
| `privacy.md` | Privacy Policy | `orbitbrain2.netlify.app/privacy` |
| `terms.md` | Terms of Use | `orbitbrain2.netlify.app/terms` |
| `support.md` | Support / FAQ page | `orbitbrain2.netlify.app/support` |

## Placeholders to fill in

Each file uses `{{ ... }}` for things only you can fill:

- `{{ replace with launch date }}` — the App Store release date
- `{{ your legal name or company }}` — the entity that signs the
  contract with Apple. Either your full name (if shipping as an
  individual) or your LLC / corp name.
- `{{ your jurisdiction }}` — for governing law in Terms of Use.
  Example: "the State of California, USA".
- `{{ current year }}` — for footers.

## URLs

The iOS app already links to:

- `https://orbitbrain2.netlify.app/privacy`
- `https://orbitbrain2.netlify.app/terms`
- `https://orbitbrain2.netlify.app/support`

Make sure these three routes return real HTML, not 404, before
TestFlight. Apple Review hits them.

## After launch

- Update `app-store-listing.md` → **What's New** for each release.
- Update `privacy.md` → **Effective Date** + content if data
  practices change.
- The **Promotional Text** in App Store Connect is editable without
  a binary update — use it to call out time-bound things
  (sales, new features just shipped).
