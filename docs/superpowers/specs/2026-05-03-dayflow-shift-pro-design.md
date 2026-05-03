# Dayflow Shift Pro Design

## Goal

Make shifts useful beyond colored calendar dots by adding shift time windows, payroll math, overtime, conflict warnings, export text, and stats presentation.

## Scope

This step intentionally excludes Apple Watch and Live Activity. Those need separate targets/capabilities. The first product slice should strengthen the existing calendar and stats screens with local-only data.

## Product Rules

- Each shift kind can have a default start/end time.
- A shift can cross midnight; duration uses the next day when end time is earlier than start time.
- Each worked shift can have an hourly rate.
- Night shifts can have a multiplier.
- Overtime starts after a configurable threshold and uses an overtime multiplier.
- Rest and recovery default to zero paid hours unless the user changes settings later.
- Dayflow can calculate one day and one calendar month payroll summary.
- Dayflow can produce a plain text export/share summary for a month.
- Dayflow detects simple conflicts between a paid shift window and scheduled activities on the same day.

## Data Model

- `ShiftPaySettings`: start/end minutes, hourly rate, pay multiplier, overtime threshold, overtime multiplier.
- `ShiftWorkdaySummary`: selected date, shift kind, start/end text, hours, regular/overtime hours, estimated pay.
- `ShiftMonthPayrollSummary`: month range, worked days, total hours, overtime hours, estimated pay, conflicts.
- `ShiftConflict`: activity vs shift-window overlap.

## UI

- Calendar selected-day panel shows shift time, hours, estimated pay, and conflict warning.
- Schedule builder gets a compact `Оплата и время` block for day/night settings.
- Stats screen gets a payroll block with month/week totals and selected shift summary.
- Share/export uses SwiftUI `ShareLink` with generated text where available.

## Testing

- Core tests cover overnight duration, multiplier pay, overtime, rest-day zero pay, monthly totals, conflict detection, and export text.
- Existing schedule tests remain valid through backward-compatible decoding/defaults.
- App build verifies SwiftUI integration.
