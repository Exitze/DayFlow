# Dayflow Shift Pro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add shift time windows, payroll math, conflict detection, export text, and stats presentation.

**Architecture:** Extend `ShiftSchedule` with backward-compatible pay/time settings. Add store summary methods that calculate workday/month payroll and conflict data from existing activities and day details. Surface summaries in Calendar and Stats without creating a new tab.

**Tech Stack:** Swift, SwiftUI, UserDefaults Codable storage, XCTest via `swift test`, app verification via `xcodebuild`.

---

### Task 1: Core Shift Payroll Model

**Files:**
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayActivityModel.swift`
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Tests/DayflowCoreTests/DayPlanStoreTests.swift`

- [ ] Write failing tests for overnight shift duration, day/night default settings, multiplier pay, overtime pay, and rest zero pay.
- [ ] Run `swift test` and confirm tests fail because payroll symbols do not exist.
- [ ] Add `ShiftPaySettings`, `ShiftWorkdaySummary`, and backward-compatible `ShiftSchedule` settings.
- [ ] Run `swift test` and confirm core payroll tests pass.

### Task 2: Store Summaries, Conflicts, Export

**Files:**
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayPlanStore.swift`
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Tests/DayflowCoreTests/DayPlanStoreTests.swift`

- [ ] Write failing tests for month payroll totals, activity conflict detection, and export text.
- [ ] Add `shiftWorkdaySummary(for:)`, `shiftPayrollSummary(from:to:)`, `shiftPayrollSummary(forMonthContaining:)`, and `shiftExportText(forMonthContaining:)`.
- [ ] Run `swift test`.

### Task 3: Calendar And Stats UI

**Files:**
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayflowCalendarView.swift`
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayflowHomeView.swift`

- [ ] Add selected-day shift summary block to Calendar.
- [ ] Add pay/time controls to Schedule Builder for day and night.
- [ ] Add payroll block to Stats.
- [ ] Add `ShareLink` export where available.
- [ ] Run app build.

### Task 4: Verification And Push

**Files:**
- All modified files.

- [ ] Run `swift test`.
- [ ] Run `git diff --check`.
- [ ] Run `xcodebuild -quiet build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.
- [ ] Commit and push to `main`.
