# Dayflow Habits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class habits with goals, progress history, grace skips, and streaks while preserving the existing fast activity workflow.

**Architecture:** Introduce habit definitions and logs in the core model/store. Generate normal `DayActivity` rows from matching habits so Home, Calendar, Stats, Widgets, and Notifications keep using the existing activity pipeline. Add a compact `Дело / Привычка` mode to `NewActivitySheet`.

**Tech Stack:** Swift, SwiftUI, Combine, UserDefaults App Group storage, XCTest via `swift test`, app verification via `xcodebuild`.

---

### Task 1: Core Habit Model

**Files:**
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayActivityModel.swift`
- Test: `/Users/danyaczhan/Desktop/Dayflow/Tests/DayflowCoreTests/DayPlanStoreTests.swift`

- [ ] Add failing tests for habit creation, generated activity metadata, completion logs, skip logs, streaks, and notes.
- [ ] Run `swift test` and verify the new tests fail because habit symbols do not exist.
- [ ] Add `DayHabitGoalUnit`, `DayHabitGoal`, `DayHabitLogStatus`, `DayHabit`, `DayHabitLog`, and `DayHabitProgress`.
- [ ] Add optional habit metadata to `DayActivity`.
- [ ] Run `swift test` and fix model compile errors only.

### Task 2: Store Persistence And Materialization

**Files:**
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayPlanStore.swift`
- Test: `/Users/danyaczhan/Desktop/Dayflow/Tests/DayflowCoreTests/DayPlanStoreTests.swift`

- [ ] Extend `DayActivityStorage` and both storage implementations with habits and habit logs.
- [ ] Load, save, migrate, and reset habit state.
- [ ] Add `addHabit`, `materializeHabits`, `recordHabitProgress`, `skipHabit`, `habitProgress`, and `habitHistory`.
- [ ] Update `activities(on:)`, `setCompleted`, and `remove` to keep habit rows and logs synchronized.
- [ ] Run `swift test` and verify the habit tests pass.

### Task 3: Add Sheet UI

**Files:**
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayflowHomeView.swift`
- Modify: `/Users/danyaczhan/Desktop/Dayflow/Dayflow/DayflowCalendarView.swift`

- [ ] Extend `NewActivitySheet` with `onSaveHabit`.
- [ ] Add `Дело / Привычка` mode selector.
- [ ] Add habit goal controls for count/minutes.
- [ ] Default habit repeat to daily when no repeat is chosen.
- [ ] Update Home and Calendar sheet call sites.

### Task 4: Verification

**Files:**
- All modified files.

- [ ] Run `swift test`.
- [ ] Run `git diff --check`.
- [ ] Run `xcodebuild -quiet build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.
- [ ] Commit and push to `main`.
