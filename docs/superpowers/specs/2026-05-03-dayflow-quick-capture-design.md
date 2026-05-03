# Dayflow Quick Capture Design

## Goal

Make adding activities feel instant: type `зал 20:00`, tap a template, repeat yesterday, or open quick add from the widget.

## Scope

- Replace the old activity form with a faster capture sheet used by Home and Calendar.
- Keep all data local in the existing `DayPlanStore` and shared App Group storage.
- Add selected-date support by passing the target date into the sheet.
- Add widget entry into quick add through a `dayflow://quick-add` deep link.
- Do not implement text input inside the widget, because iOS widgets cannot host arbitrary keyboard entry.

## Core Behavior

- `DayflowQuickCaptureParser` parses short text into `NewDayActivity`.
- Recognized examples include `зал 20:00`, `бег 7:30`, `вода`, `сон`, `работа`, `медитация`.
- Known templates provide title, default time, detail, category, icon, and accent.
- Unknown text still works as a personal task if it has or receives a fallback time.
- `DayPlanStore.repeatActivities(from:to:)` copies a source day to a target day, resets completion, and skips exact duplicates.

## UI Behavior

- Home add uses today.
- Calendar add uses the currently selected date.
- The sheet shows target date, quick input, parsed preview, template chips, repeat-yesterday action, and save.
- The old detailed fields stay available inside the same sheet for category, time, and detail editing after quick text is parsed.

## Widget Behavior

- Plan widget exposes a `+` affordance.
- Tapping it opens the app using `dayflow://quick-add`.
- The app switches to Home and opens quick capture for today.

## Testing

- Parser tests cover known templates, explicit time, default template time, and unknown custom tasks.
- Store tests cover repeating yesterday, resetting completion, assigning the target day, and duplicate prevention.
- App build verifies SwiftUI and widget integration.
