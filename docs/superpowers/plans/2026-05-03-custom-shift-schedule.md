# Custom Shift Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add fast and custom automatic shift schedule filling to the calendar.

**Architecture:** Extend the pure schedule model with a `ShiftScheduleFormula` that builds cycles from counts. Update the SwiftUI calendar schedule block to open a setup sheet that creates and applies `ShiftSchedule` values.

**Tech Stack:** Swift, SwiftUI, XCTest, existing `DayPlanStore` persistence.

---

### Task 1: Model And Tests

**Files:**
- Modify: `Dayflow/DayActivityModel.swift`
- Modify: `Tests/DayflowCoreTests/DayPlanStoreTests.swift`

- [ ] Add tests for `День/Ночь`, `5/2`, and custom formula cycles.
- [ ] Implement `ShiftScheduleFormula`.
- [ ] Add `ShiftSchedule.makeCustom(formula:starting:calendar:)`.
- [ ] Run `swift test`.

### Task 2: Calendar Builder UI

**Files:**
- Modify: `Dayflow/DayflowCalendarView.swift`

- [ ] Add sheet state to `DayflowCalendarView`.
- [ ] Replace inline preset row with `Заполнить график`.
- [ ] Add `ScheduleBuilderSheet`, quick option cards, custom steppers, preview chips, and apply action.
- [ ] Run `xcodebuild -quiet build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.

### Task 3: Verification And Commit

**Files:**
- Verify all touched files.

- [ ] Run `swift test`.
- [ ] Run iOS simulator build.
- [ ] Commit and push.

