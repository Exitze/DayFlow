# Dayflow Habits Design

## Goal

Separate habits from regular tasks without forcing a new workflow. A user can still add something from the same fast sheet, but can switch the item type from `Дело` to `Привычка` when the activity needs a streak, goal, skip, counter, note, and history.

## Product Shape

- `Дело` stays the default: one normal activity, optionally recurring through the existing repeat rules.
- `Привычка` creates a habit definition and materializes matching days into normal activity rows.
- Habit rows can be completed from Home, Calendar, and widgets like regular activities.
- Deleting a materialized habit row records a grace skip for that day instead of destroying the habit.

## Habit Rules

- Habits use the same repeat patterns as recurring activities: daily, weekdays, selected dates, shift kinds, and after-night.
- A habit has a goal value and unit: count or minutes.
- Completing the generated activity records a completion log using the full goal value.
- Recording a smaller value keeps partial progress in history without completing the row.
- A skipped day does not increment the streak and does not break it.
- A missed scheduled day with no log breaks the streak.

## Data Model

- `DayHabit`: reusable definition with title, time, detail, category, icon, accent, goal, repeat pattern, start day, and enabled state.
- `DayHabitLog`: one history record per habit/day with value, status, and optional completion note.
- `DayActivity`: gains optional habit metadata so generated habit rows can still flow through existing UI, calendar, stats, widgets, and notifications.

## UI

- `NewActivitySheet` gets a segmented mode: `Дело` / `Привычка`.
- Habit mode shows goal controls: value stepper and unit selector.
- Repeat controls are reused. If a user selects habit mode with no repeat, Dayflow defaults to daily, because a non-repeating habit is just a task.
- Existing activity cards show a small habit marker and goal text for habit-generated rows.

## Testing

- Core tests cover creating a habit, materializing rows, completing logs, partial counter progress, grace skips, streak behavior, note history, persistence, and reset.
- UI build verifies the new SwiftUI controls compile in both Home and Calendar add sheets.
