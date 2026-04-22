# Fastlane

Release automation for Bike Action Denver.

## One-time setup

1. **Install fastlane** (ships with its own Ruby — avoids wrestling rbenv):

   ```sh
   brew install fastlane
   ```

2. **App Store Connect API key** (avoids 2FA prompts; works in CI):

   - Go to https://appstoreconnect.apple.com/access/api
   - Generate a key with "Developer" or "Admin" access
   - Download the `.p8` (you only get one chance — stash it at `~/.appstoreconnect/`)

3. **Export env vars** (add to `~/.zshrc`):

   ```sh
   export ASC_KEY_ID="ABC123XYZ"                                   # Key ID
   export ASC_ISSUER_ID="69a6de7f-xxxx-xxxx-xxxx-xxxxxxxxxxxx"     # Issuer ID (top of the Keys page)
   export ASC_KEY_FILEPATH="$HOME/.appstoreconnect/AuthKey_ABC123XYZ.p8"
   ```

4. **App must exist in App Store Connect** before the first upload. Create it at https://appstoreconnect.apple.com/apps with:

   - Bundle ID: `ink.sam.bikelanes`
   - Platform: iOS
   - SKU: anything unique (e.g. `bike-action-denver`)
   - Primary language: English (U.S.)

## Lanes

| Lane | What it does |
|------|--------------|
| `gen` | Regenerates `BikeLanes.xcodeproj` from `project.yml` via XcodeGen. |
| `test` | Runs unit + UI tests on iPhone 15 Pro simulator. |
| `build` | Regens, then archives a Release `.ipa` into `build/fastlane/`. |
| `beta` | Builds, uploads to TestFlight. |
| `release` | Builds, uploads to App Store Connect (review trigger is manual). |

Run any lane with:

```sh
fastlane ios <lane>
```

Most common workflow:

```sh
fastlane ios beta       # → TestFlight
fastlane ios release    # → App Store (upload only; review triggered manually)
```

## Build numbers

Each `build` uses a timestamp-based `CURRENT_PROJECT_VERSION` (e.g. `2604221805`)
passed as an `xcargs` override rather than mutating `project.pbxproj`. This
survives `xcodegen generate` (which resets `CURRENT_PROJECT_VERSION` back to
whatever's in `project.yml`). Override by exporting `BUILD_NUMBER` before
running a lane if you need reproducible builds.

## Notes

- The Fastfile runs `xcodegen generate` at the top of every lane so the Xcode
  project always matches `project.yml`.
- `submit_for_review` is off in the `release` lane — we upload the build, then
  trigger review manually in App Store Connect once metadata/screenshots land.
- Metadata and screenshots live in App Store Connect for now. To automate them
  later, wire up `fastlane deliver` with a `metadata/` + `screenshots/` tree.
