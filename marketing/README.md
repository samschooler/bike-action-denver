# Marketing assets

App Store screenshot templates for Bike Action Denver.

## Status

Five App Store screenshot templates generated at the **iPhone 6.9"** required
spec (`1320×2868` PNG, sRGB, no alpha — verified). Each has:

- On-brand cream → sage background (screen #1 uses a Higgsfield-generated Rocky
  Mountain watermark; #2–#5 are programmatic gradients).
- Headline (Georgia Bold, falls back to system serif — swap to Fraunces when a
  TTF is on disk).
- Subhead.
- Rounded phone-shaped placeholder where the real app UI goes.

## Files

```
marketing/
├─ backgrounds/
│  ├─ 01-hero-bg.png       # Higgsfield Nano Banana Pro — cream → sage + chevron watermark
│  ├─ 02-capture-bg.png    # Programmatic gentle vertical gradient
│  ├─ 03-detect-bg.png     # Solid cream
│  ├─ 04-submit-bg.png     # Programmatic cream → sage diagonal
│  └─ 05-track-bg.png      # Solid cream + Rocky Mountain silhouette band
├─ screenshots/            ← what you upload to App Store Connect
│  ├─ 01-hero.png          # "Clear the bike lane."
│  ├─ 02-capture.png       # "One photo. That's it."
│  ├─ 03-detect.png        # "Reads the plate for you."
│  ├─ 04-submit.png        # "You confirm. We submit."
│  └─ 05-track.png         # "Watch the city respond."
└─ compose.py              # drops a real app screenshot into the phone placeholder
```

## Finishing the screenshots

The phone placeholder in each template is a `(W * 0.66) × (W * 0.66 * 2.164)`
rounded-rect centered at `y = H * 0.36`. Capture app UI screenshots from the
iPhone 15 Pro Max simulator (matches 6.9" physical display exactly), then:

```sh
# 1) Boot the 6.9" simulator and install the app
xcrun simctl boot "iPhone 15 Pro Max"
xcodegen generate -s BikeLanes/project.yml --project BikeLanes
xcodebuild -scheme BikeLanes -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' install

# 2) Navigate through each of the 5 states described in `screenshots/`
#    01 hero: sign-in screen OR empty "Add a photo" state
#    02 capture: camera viewer showing vehicle in bike lane
#    03 detect: report screen with bbox + plate recognized
#    04 submit: confirmation alert (iOS modal)
#    05 track: history tab with status pills

# 3) For each state, capture a screenshot:
xcrun simctl io booted screenshot marketing/app-frames/01.png

# 4) Compose into the template:
python3 marketing/compose.py 01
```

## App Store Connect technical spec (as confirmed by the subagent audit)

- **Dimensions:** `1290×2796`, `1320×2868`, or `1260×2736` (portrait, iPhone 6.9")
- **Format:** PNG (no alpha) or JPEG, sRGB
- **Count:** 1–10 per display size
- **Content:** must show real app UI (§2.3.3) — marketing text + device frames OK
- **Safe practices:** status bar `9:41`, full bars, 100% battery, no real PII

Upload only the 6.9" set; Apple scales down for 6.5"/6.3"/6.1"/5.5"/4.7".
