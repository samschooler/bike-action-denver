# App Store Privacy Nutrition Label — Bike Lanes v0.1

Reference for App Store Connect "App Privacy" configuration when submitting v0.1 for review.

## Data collected (linked to user, used for app functionality)

| Data type   | Purpose                           | Where it goes            |
|-------------|-----------------------------------|--------------------------|
| Photos      | Evidence of the reported vehicle  | Denver 311 `/api/cases/attachments` (denvergov.org) |
| Coarse Location | Pin the report on a street    | Denver 311 `/api/cases`; CLGeocoder for reverse-geocoding (Apple) |

## Tracking

**No.** No third-party SDKs, no analytics, no tracking identifiers.

## Data NOT collected

- Contact info (name, email, phone) — we file as anonymous
- Identifiers (IDFA, device ID)
- Usage data / diagnostics
- Financial info
- Health & fitness
- Search history
- User content other than photos + free-text notes

## App Store Connect entry steps

1. Open the app's App Privacy section in App Store Connect.
2. Click "Get Started" → "Data Types."
3. Under "Photos or Videos": ✓ "Yes, we collect data from this app" → "Linked to user" = Yes → Purpose = "App Functionality" → Share with third parties = Yes (Denver 311).
4. Under "Coarse Location": same answers as above.
5. All other categories: "No, we do not collect this."
6. Tracking: "No."

## Privacy policy URL

TBD — host a minimal privacy policy at e.g. `https://sam.ink/bike-lanes/privacy`. Content should summarize: what data we send, where, that it's anonymous by default, how to request deletion. Link it from SettingsView (already wired to this URL).
