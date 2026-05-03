# Dayflow Recurring Activities Design

## Goal

Add recurring activities so routines like water, sleep, gym, run, and meditation do not need manual entry every day.

## Product Rules

- A recurring activity is stored as a reusable rule.
- Dayflow materializes matching rules into normal `DayActivity` rows for the selected date.
- Materialized activities behave like regular activities: they can be completed, deleted, shown in calendar, counted in stats, and shown in widgets.
- Reopening the same day must not create duplicates.

## Recurrence Patterns

- Daily.
- Selected weekdays.
- Selected calendar dates.
- Matching shift types: day, night, recovery, rest.
- After night shift: creates the activity when the previous day was a night shift.

## Storage

- Extend local App Group storage with recurrence rules.
- Extend storage with recurrence skips so deleting one generated activity does not recreate it forever.
- Existing users decode with empty recurrence state.

## UI

- The quick capture sheet gains a `Повтор` section.
- The default is `Без повтора`.
- Weekday mode shows weekday chips.
- Selected dates mode shows a short date strip from the target date.
- Shift mode shows shift chips.
- Saving with a repeat rule creates the rule and materializes the target day if it matches.

## Testing

- Core tests cover daily, weekdays, selected dates, shift matching, after-night matching, duplicate prevention, completion persistence, and delete skip behavior.
- Existing quick capture tests remain valid.
- App build verifies SwiftUI and widget integration.
