# Sift site

`index.html` is the marketing/home page — it also serves as the "Website" field on
Apple's [FinanceKit entitlement request](https://developer.apple.com/contact/request/financekit),
which wants a real, findable site behind the request. `privacy/` and `terms/` are the two
legal pages that must be live and reachable **before** external TestFlight review — App
Review checks the privacy policy URL and rejects builds where it 404s.

Published at:

- <https://tanjiro05-netizen.github.io/Finance-Planner/>
- <https://tanjiro05-netizen.github.io/Finance-Planner/privacy/>
- <https://tanjiro05-netizen.github.io/Finance-Planner/terms/>

The app links to them from Settings. Those URLs are built in one place:
`ios/Sift/Core/Domain/LegalLinks.swift`.

## Before publishing

Replace every `REPLACE_WITH_` placeholder in `privacy/index.html` and `terms/index.html`:

| Placeholder | Value |
|---|---|
| `REPLACE_WITH_DATE` | Publication date, e.g. `12 August 2026` |
| `REPLACE_WITH_COUNSEL_DRAFTED_SECTION` | Disclaimers and liability, in `terms/index.html` only |

```sh
grep -rn "REPLACE_WITH" --include="*.html" site/    # must return nothing
```

(The `--include` matters: this README lists the placeholder names, so an unscoped grep
always matches itself. The deploy workflow scans the same narrowed way.)

The deploy workflow fails on purpose while any placeholder remains, so a half-finished
policy cannot go live by accident.

**Counsel must review before publishing.** `docs/PRIVACY_POLICY_DRAFT.md` and
`docs/TERMS_DRAFT.md` carry notes on what still needs their input — governing law,
jurisdiction, GDPR/UK GDPR framing, CCPA/CPRA disclosures.

## Turning Pages on (one time)

1. Repository → **Settings** → **Pages**
2. **Source: GitHub Actions** — *not* "Deploy from a branch"

That is all. `.github/workflows/pages.yml` publishes `site/` on every push to `main` that
touches it, and can be run manually from the Actions tab.

Source must be **GitHub Actions** because branch deploys only offer the repository root or
`/docs`, and `/docs` here holds internal phase notes that should not be on the public web.

## The home page

`index.html` + `home.css` share `styles.css`'s color tokens with the legal pages (same
ink/bone/gold palette as the app icon) so the whole site reads as one product, but it's
the one page that loads a web font — Shippori Mincho B1, from Google Fonts, used only for
the headline and the pull-quote statement line. Everything else stays in the system font
stack the legal pages use, so that's a deliberate, scoped exception, not drift.

The vertical line of type beside the headline (`篩`, *furui* — "a sieve; to sift") is a
real word, not decorative kanji: `writing-mode: vertical-rl` renders it top-to-bottom,
the traditional Japanese reading direction, as a small aside rather than a page-wide
motif.

## Why the layout looks like this

- **`privacy/index.html`, not `privacy.html`** — serves at `/privacy/` with no `.html`
  suffix, which is what the app links to.
- **`styles.css`, not `_shared.css`** — Jekyll ignores paths beginning with an underscore,
  so the stylesheet would have 404'd.
- **`.nojekyll`** — belt and braces, disabling Jekyll processing entirely.

## Verifying before submission

```sh
curl -sSI https://tanjiro05-netizen.github.io/Finance-Planner/privacy/ | head -1   # 200
curl -sSI https://tanjiro05-netizen.github.io/Finance-Planner/terms/   | head -1   # 200
```

Then open Settings in the app on a device and tap both rows — they should open in Safari
rather than failing silently.

## If the URL ever changes

Edit `host` and `basePath` in `ios/Sift/Core/Domain/LegalLinks.swift`. A custom domain
served at the root means `basePath = ""`.
