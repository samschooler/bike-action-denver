# Fastlane

Release automation for Bike Action Denver.

## One-time setup

1. **Ruby + bundler** (any Ruby 3.x works):

   ```sh
   brew install rbenv
   rbenv install 3.3.0 && rbenv global 3.3.0
   gem install bundler
   ```

2. **Install gems:**

   ```sh
   bundle install
   ```

3. **App Store Connect API key** (avoids 2FA prompts; works in CI):

   - Go to https://appstoreconnect.apple.com/access/api
   - Generate a key with "Developer" or "Admin" access
   - Download the `.p8` (you only get one chance — store it somewhere safe like `~/.appstoreconnect/`)

4. **Export env vars** (add to `~/.zshrc` or a private `.env`):

   ```sh
   export ASC_KEY_ID="ABC123XYZ"                               # Key ID from App Store Connect
   export ASC_ISSUER_ID="69a6de7f-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Issuer ID from the same page
   export ASC_KEY_FILEPATH="$HOME/.appstoreconnect/AuthKey_ABC123XYZ.p8"
   ```

5. **App must exist in App Store Connect** before the first upload. Create it manually at https://appstoreconnect.apple.com/apps with:

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

### Build numbers

Each `build` uses a timestamp-based `CURRENT_PROJECT_VERSION` (e.g. `2604221805`)
passed as an `xcargs` override rather than mutating `project.pbxproj`. This
survives `xcodegen generate` (which resets `CURRENT_PROJECT_VERSION` back to
whatever's in `project.yml`). Override by exporting `BUILD_NUMBER` before
running a lane if you need reproducible builds.

Run any lane with:

```sh
bundle exec fastlane ios <lane>
```

For a TestFlight-ready beta (most common):

```sh
bundle exec fastlane ios beta
```

For a new App Store submission (run after adding metadata/screenshots via the App Store Connect web UI, until we wire up `fastlane deliver`):

```sh
bundle exec fastlane ios release
```

## Notes

- The Fastfile runs `xcodegen generate` in `before_all` so the Xcode project always matches `project.yml`.
- `submit_for_review` is off in the `release` lane — we upload the build, then trigger review manually in App Store Connect once metadata/screenshots are in place.
- Screenshots and metadata live in App Store Connect for now. To automate them later, run `bundle exec fastlane init_platforms` and add a `metadata/` + `screenshots/` tree.
