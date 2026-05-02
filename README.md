# Dayflow

Dayflow is a native SwiftUI iOS planner for daily activities, calendar shifts, notes, and progress statistics.

The current build is local-first:

- activities are stored on device;
- calendar notes and shift overrides are stored on device;
- automatic shift schedules support common work patterns such as `2/2`, `2/5`, and day/night cycles;
- the app does not use accounts, analytics, advertising SDKs, or tracking.

## Project

- `Dayflow/` - SwiftUI app source, assets, fonts, privacy manifest, and app plist.
- `Tests/DayflowCoreTests/` - SwiftPM tests for planning, calendar, shifts, statistics, privacy, and release-readiness logic.
- `AppStore/` - App Store preparation documents.
- `docs/` - public GitHub Pages site for Privacy Policy, Terms, and Support.

## Verification

```bash
swift test
xcodebuild -quiet build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## App Store Status

Project-side release preparation is partially complete:

- `PrivacyInfo.xcprivacy` declares no tracking, no collected data, and `UserDefaults` reason `CA92.1`.
- `ITSAppUsesNonExemptEncryption` is set to `false`.
- The app includes local Privacy Policy, Terms, Support, and release-readiness screens.

External App Store Connect work is still required before review:

- Apple Developer Program membership;
- public Privacy Policy URL;
- public Support URL;
- App Store metadata, screenshots, privacy label, TestFlight, and final review submission.
