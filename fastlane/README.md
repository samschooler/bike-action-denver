fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios gen

```sh
[bundle exec] fastlane ios gen
```

Regenerate Xcode project from project.yml via XcodeGen

### ios register

```sh
[bundle exec] fastlane ios register
```

Register the App ID in the Apple Developer portal + create the App Store Connect listing

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit + UI tests

### ios build

```sh
[bundle exec] fastlane ios build
```

Archive a release .ipa into build/fastlane/

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload the current build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit current build to the App Store (manual review trigger)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
