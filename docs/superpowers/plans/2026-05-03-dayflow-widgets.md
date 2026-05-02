# Dayflow Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build native WidgetKit widgets for Dayflow with real shared data, interactive completion, and the approved black/lime Dayflow visual style.

**Architecture:** Move app data to an App Group-backed `UserDefaults` suite with legacy migration, add a pure snapshot/action layer testable through SwiftPM, then add a WidgetKit app extension target that renders the snapshot and calls the action layer through App Intents.

**Tech Stack:** Swift 5, SwiftUI, WidgetKit, AppIntents, XcodeGen, XCTest, UserDefaults App Group storage.

---

## Files

- Modify: `Dayflow/DayPlanStore.swift` for App Group storage, migration, and widget action service.
- Create: `Dayflow/DayflowWidgetSnapshot.swift` for widget snapshot models and builder.
- Modify: `Tests/DayflowCoreTests/DayPlanStoreTests.swift` for shared storage, migration, snapshot, and action tests.
- Modify: `Package.swift` to include `DayflowWidgetSnapshot.swift` and exclude app-only files.
- Create: `Dayflow/Dayflow.entitlements` and `DayflowWidget/DayflowWidget.entitlements`.
- Create: `DayflowWidget/DayflowWidget.swift`, `DayflowWidget/DayflowWidgetBundle.swift`, `DayflowWidget/CompleteActivityIntent.swift`, `DayflowWidget/Info.plist`, `DayflowWidget/PrivacyInfo.xcprivacy`.
- Modify: `project.yml` to add the widget extension target, App Group entitlements, and target dependency.
- Regenerate: `Dayflow.xcodeproj/project.pbxproj` via `xcodegen`.

## Task 1: Shared Storage and Migration

- [ ] Write failing tests:
  - `testUserDefaultsStorageMigratesLegacyDataToSharedStorage`
  - `testMigrationDoesNotOverwriteExistingSharedStorage`
- [ ] Run `swift test` and verify those tests fail because migration APIs do not exist.
- [ ] Add `DayflowAppGroup.identifier`, `UserDefaultsActivityStorage.sharedAppGroupStorage`, and `DayflowStorageMigration.migrateIfNeeded`.
- [ ] Change `DayPlanStore()` to use shared App Group storage and run migration from legacy standard storage.
- [ ] Run `swift test` and verify green.

## Task 2: Widget Snapshot and Action Core

- [ ] Write failing tests:
  - `testWidgetSnapshotUsesRealTodayData`
  - `testWidgetSnapshotBuildsWeeklyPulse`
  - `testWidgetActionCompletesActivity`
  - `testWidgetActionIsIdempotentForCompletedActivity`
- [ ] Run `swift test` and verify failures because snapshot/action APIs do not exist.
- [ ] Create `DayflowWidgetSnapshot.swift` with snapshot structs, builder, and next-activity selection.
- [ ] Add `DayflowWidgetActionService.completeActivity`.
- [ ] Update `Package.swift`.
- [ ] Run `swift test` and verify green.

## Task 3: Widget Extension Target

- [ ] Create widget target files under `DayflowWidget/`.
- [ ] Create app and widget entitlements with `group.com.exitze.dayflow`.
- [ ] Update `project.yml` with widget extension target and app dependency.
- [ ] Run `xcodegen generate`.
- [ ] Run `xcodebuild -list -project Dayflow.xcodeproj` and verify `DayflowWidgetExtension` appears.

## Task 4: Widget UI and Interactivity

- [ ] Implement `DayflowPlanWidget` with system small, medium, large, and accessory rectangular families.
- [ ] Implement `DayflowShiftWidget` with system small and accessory rectangular families.
- [ ] Implement `CompleteActivityIntent` using shared storage and `WidgetCenter.reloadAllTimelines()`.
- [ ] Keep layout aligned to the approved v2 visual direction: black panels, Unbounded display type, lime progress, rose night state, stable widget dimensions.

## Task 5: Verification and Commit

- [ ] Run `swift test`.
- [ ] Run `xcodebuild -quiet build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.
- [ ] Inspect the built app for `PlugIns/DayflowWidgetExtension.appex`.
- [ ] Commit implementation.
- [ ] Push `main` to GitHub.
