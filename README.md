# Swiftlet

An iOS expense tracker for everyday spending in Indonesian rupiah. It works offline and doesn't need an account.

## What it does

- Log income and expenses with a category, a note, and a money source (Grab, GoPay, BCA, BNI, OVO, QRIS).
- Type entries in plain language, like `lunch at Padang 25k`. Shorthand amounts such as `20k`, `1.5jt`, `3 juta`, and `20 ribu` all work. On devices with Apple Intelligence the parsing and category suggestions run on the device.
- Scan a receipt photo. Swiftlet reads the line items on the device, and when you tick the ones you paid for it splits shared tax, service charge, and discount across them by proportion.
- Add or check transactions through Siri without opening the app.
- Import existing records from a JSON file.
- The Home tab shows running totals and a category breakdown.

Sign in with Apple is optional. If you do, data syncs across your devices through your own private iCloud (CloudKit); it never touches our servers and is never used for tracking or ads.

## Requirements

- Xcode 26.6
- iOS 26.5 deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project file

## Build

The Xcode project is generated from `project.yml`:

```bash
xcodegen generate
```

Then build for the simulator:

```bash
xcodebuild -project Swiftlet.xcodeproj -scheme Swiftlet -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Project layout

- `Shared` — code both apps compile: SwiftData models and the persistence container, services, view models and design tokens.
- `Swiftlet/Views` — SwiftUI screens, grouped by feature (Home, Transactions, Add, Bills, Account, Auth).
- `SwiftletMac` — the native Mac app: sidebar, transaction table, dashboard, menu bar quick add.
- `Swiftlet/AppIntents` — Siri and App Intents support.
- `SwiftletShareExtension` — share-sheet target for sending a receipt image into the app.
- `fastlane` — TestFlight and App Store build and metadata lanes. See `fastlane/README.md`.
- `docs` — the privacy and support pages published to GitHub Pages.

## Distribution

Release builds go through fastlane:

```bash
bundle exec fastlane ios beta      # upload to TestFlight
bundle exec fastlane ios release   # upload binary and metadata, submit for review
```
