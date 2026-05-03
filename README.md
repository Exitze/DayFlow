# Dayflow

**Dayflow is a local-first iOS planner for daily rhythm, shift schedules, habits, notes, reminders, widgets, and personal statistics.**

It is built for people whose day is shaped by more than a simple task list: training, sleep, work shifts, recovery days, focus sessions, and recurring routines.

<p>
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B-111111?style=flat-square">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-native-ccfa22?style=flat-square&labelColor=111111">
  <img alt="Privacy" src="https://img.shields.io/badge/privacy-local--first-ccfa22?style=flat-square&labelColor=111111">
  <img alt="Tracking" src="https://img.shields.io/badge/tracking-none-ccfa22?style=flat-square&labelColor=111111">
</p>

## What Dayflow Does

- **Daily planning:** add activities, focus tasks, routines, notes, and reminders for specific days.
- **Calendar rhythm:** move between dates, preserve historical tasks, and keep completed or unfinished activities tied to the day they belong to.
- **Shift scheduling:** generate work patterns such as 2/2, 5/2, day/night/recovery/rest, and custom formulas.
- **Habits and recurrence:** repeat activities daily, by weekdays, selected dates, or shift type.
- **Statistics:** track weekly and monthly progress, category completion, habits, shift load, overtime, and payroll breakdowns.
- **Widgets:** native WidgetKit widgets for quick progress, next actions, and shift state.
- **Local notifications:** on-device reminders for morning plans, activities, upcoming shifts, and evening review.

## Product Principles

Dayflow is designed around three commitments:

1. **Local-first:** no account, no server dependency, no advertising SDKs, no tracking.
2. **Apple-native:** SwiftUI, WidgetKit, App Intents, local notifications, privacy manifests, and App Group storage.
3. **Fast daily capture:** quick add, templates, repeat yesterday, recurring rules, and selected-date planning.

## App Store Readiness

The project includes the release-side work that can be prepared in code:

- App bundle: `com.exitze.dayflow`
- Widget bundle: `com.exitze.dayflow.widget`
- App Group: `group.com.exitze.dayflow`
- Export compliance flag: `ITSAppUsesNonExemptEncryption = false`
- Privacy manifests for the app and widget extension
- Required reason API declaration for `UserDefaults` with reason `CA92.1`
- In-app Privacy Policy, Terms, and Support screens
- Public GitHub Pages documents for App Store Connect metadata
- Local data reset controls in Settings
- Widget extension embedded in the main app target

Public release URLs:

- Privacy Policy: <https://exitze.github.io/DayFlow/privacy.html>
- Support: <https://exitze.github.io/DayFlow/support.html>
- Terms: <https://exitze.github.io/DayFlow/terms.html>
- Product page: <https://exitze.github.io/DayFlow/>

App Store Connect copy and review notes are prepared in [AppStore/AppStoreMetadata.md](AppStore/AppStoreMetadata.md). The full release checklist is in [AppStore/ReleaseChecklist.md](AppStore/ReleaseChecklist.md).

## Architecture

```text
Dayflow/
  SwiftUI app, models, storage, notifications, widgets snapshot layer, assets, fonts
DayflowWidget/
  WidgetKit extension, App Intents, small and medium widget layouts
Tests/DayflowCoreTests/
  Core tests for planning, calendar, shifts, habits, widgets, privacy, and release logic
AppStore/
  Privacy Policy, Terms, Support, metadata, checklist, and brand assets
docs/
  Public GitHub Pages site used for App Store URLs
```

Core data is stored through a `DayActivityStorage` abstraction backed by an App Group `UserDefaults` suite. The same storage powers the app and WidgetKit extension, with migration from legacy standard `UserDefaults` for existing installs.

## Build

Requirements:

- Xcode 16 or newer
- iOS 17 deployment target
- Swift 5 toolchain
- Apple Developer account for device signing, widgets, and App Groups

Useful commands:

```bash
swift test
xcodebuild -scheme Dayflow -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For a real App Store archive, open `Dayflow.xcodeproj`, select the `Dayflow` scheme, set the Apple team, confirm App Groups for the app and widget identifiers, then archive from Xcode.

## Privacy

The current version does not collect user data. Activities, notes, shifts, schedules, notification preferences, statistics inputs, and widget snapshots are stored locally on device. Local notifications are scheduled on device through Apple UserNotifications. Dayflow does not use accounts, analytics SDKs, advertising SDKs, tracking domains, or server-side storage.

If future versions add sync, analytics, accounts, cloud storage, remote push notifications, or third-party SDKs, the privacy policy, App Store privacy details, and privacy manifests must be reviewed before release.

## Status

Dayflow is in active pre-release development. The repository is prepared for TestFlight/App Store workflow, but final submission still requires App Store Connect metadata entry, screenshots, signing, archive upload, TestFlight validation, and Apple review.
