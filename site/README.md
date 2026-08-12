# Sift legal pages

Two static pages that must be live and reachable **before** external TestFlight review —
App Review checks the privacy policy URL and rejects builds where it 404s.

The app links to them from Settings. The URLs are defined in one place:
`ios/Sift/Core/Domain/LegalLinks.swift`.

## Before publishing

Replace every `REPLACE_WITH_` placeholder in `privacy.html` and `terms.html`:

| Placeholder | Value |
|---|---|
| `REPLACE_WITH_DATE` | Publication date, e.g. `12 August 2026` |
| `REPLACE_WITH_SUPPORT_EMAIL` | A monitored address (appears twice per page: link text and `mailto:`) |
| `REPLACE_WITH_COUNSEL_DRAFTED_SECTION` | Disclaimers and liability, in `terms.html` only |

Check none remain:

```sh
grep -rn "REPLACE_WITH" site/
```

**Counsel must review before publishing.** The commentary in
`docs/PRIVACY_POLICY_DRAFT.md` and `docs/TERMS_DRAFT.md` lists what still needs their input
— governing law, jurisdiction, GDPR/UK GDPR framing, CCPA/CPRA disclosures.

## Hosting on GitHub Pages

1. Repository → **Settings** → **Pages**
2. Source: **Deploy from a branch**; branch `main`, folder `/site` (or move these files to
   `/docs` if you prefer that folder — Pages only offers root and `/docs` on some plans, in
   which case copy them there)
3. Add your domain under **Custom domain**, then point a `CNAME` DNS record at
   `<username>.github.io`
4. Tick **Enforce HTTPS** — Apple requires `https://`

Pages serves `privacy.html` at `/privacy.html`. The app expects `/privacy` with no
extension. Either:

- serve with a rewrite (Cloudflare Pages, Netlify and Vercel all do this natively), or
- rename the files to `privacy/index.html` and `terms/index.html`, which makes
  `/privacy` and `/terms` work on plain GitHub Pages, or
- change `LegalLinks` to include the `.html` suffix.

The middle option is usually least friction.

## If the domain is not `sift.app`

Change `LegalLinks.host` in `ios/Sift/Core/Domain/LegalLinks.swift`. That is the only
place the domain appears in the app.

Also update `LegalLinks.supportEmail` if the support address differs.

## Verifying before submission

```sh
curl -sSI https://<your-domain>/privacy | head -1   # expect 200
curl -sSI https://<your-domain>/terms   | head -1   # expect 200
```

Then open Settings in the app on a device and tap both rows — they should open in Safari,
not fail silently.
