# Custom Shift Schedule Design

## Goal

Let the user fill automatic work schedules from either fast presets or a custom formula such as `3 дня · 4 ночи · 1 отсыпной · 5 выходных`.

## Scope

- Add a calendar `Автографик` action named `Заполнить график`.
- Open a Dayflow-styled sheet for schedule setup.
- Provide quick templates: `2/2`, `День/Ночь`, `5/2`.
- Provide custom counters for `Дни`, `Ночи`, `Отсыпные`, `Выходные`.
- Convert counters into a repeating cycle in this exact order: day, night, recovery, rest.
- Show a preview for the next days before applying.
- Apply the generated schedule from the currently selected calendar date.
- Keep existing manual day overrides above automatic schedules.

## Data Model

`ShiftSchedule` keeps storing a `cycle: [ShiftKind]`, so the calendar and statistics can continue using the same `shift(on:)` logic. A new formula model creates cycles from counts and validates that at least one shift exists.

Fast presets map to concrete cycles:

- `2/2`: day, day, rest, rest.
- `День/Ночь`: day, night, recovery, rest.
- `5/2`: day, day, day, day, day, rest, rest.

Custom formula examples:

- `3 / 4 / 1 / 5`: day x3, night x4, recovery x1, rest x5.
- `0 / 2 / 1 / 3`: night x2, recovery x1, rest x3.

## UI

The inline preset cards in the calendar are replaced by one stronger `Заполнить график` button. The sheet contains quick cards first, then the custom formula controls, then a preview strip, then an apply button.

## Testing

Unit tests cover quick preset cycles, custom formula cycle creation, invalid empty formulas, and date-by-date automatic shift output.

