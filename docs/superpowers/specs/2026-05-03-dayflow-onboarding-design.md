# Dayflow Onboarding Design

## Goal

Give first-time users a fast, beautiful setup flow that explains Dayflow by creating real value: a first day plan, optional shift schedule, and starter activities.

## Product Intent

The onboarding should not behave like marketing slides. It should answer four questions through interaction:

- what Dayflow is;
- how it differs from a regular to-do list;
- what to do first;
- why shifts, routines, widgets, and daily progress belong together.

## Flow

1. Intro screen:
   - Dayflow name;
   - core promise: plan day, shifts, and personal rhythm;
   - three concrete value rows: today's activities, shifts/recovery, widgets/reminders.

2. Scenario screen:
   - `Сменный график`;
   - `Спорт и рутина`;
   - `Фокус и дела`;
   - `Простой план дня`.

3. Shift screen:
   - only required for the shift scenario in the primary path;
   - options: no shift, `2/2`, `День/Ночь`, `5/2`;
   - complex custom schedules remain available later in the calendar.

4. Starter activity screen:
   - shows recommended templates for the selected scenario;
   - selected templates are created as real activities for today.

## Data Behavior

The core onboarding model contains scenarios, activity templates, a plan, and a builder. `DayPlanStore.applyOnboarding(_:on:)` applies the plan by creating activities and an optional shift schedule.

The app stores completion with `dayflow.onboarding.completed`. Existing users with activities, day details, or a shift schedule are marked complete automatically so an update does not interrupt them.

## Visual Direction

Use the existing Dayflow language:

- black background;
- lime primary action;
- paper/mist text;
- Unbounded display typography;
- circular icons and compact rhythm marks;
- no generic iOS tutorial cards.

## Testing

Core tests cover:

- scenario recommendations;
- selected template de-duplication and schedule building;
- applying onboarding to the store.
