# Dayflow Widgets Design

## Goal

Add native iOS WidgetKit widgets that appear through the system widget gallery: long press Home Screen or Lock Screen, tap `+`, choose Dayflow, and add a widget.

The widgets must feel like Dayflow, not like generic iOS cards. The visual direction is based on the approved v2 mockup: black glass panels, heavy Unbounded typography, lime rhythm arcs, compact real data, and precise alignment.

## Widget Set

### Home Screen Small: Plan Pulse

Shows the current day's completion percentage, completed/total count, and the next open activity.

Purpose: answer “how is today going?” in one glance.

### Home Screen Small: Shift

Shows today's effective shift and schedule label, for example `Ночь`, `2/2`, or `2Д/2Н`.

Purpose: make work schedule visible without opening the app.

### Home Screen Medium: Next Actions

Shows the next two or three activities for today with compact interactive completion controls.

Purpose: let the user close a task from the widget and see progress update.

### Home Screen Large: Weekly Pulse

Shows the current week rhythm: daily completion marks, today's progress, and the current shift context.

Purpose: give the “Dayflow dashboard” feeling outside the app.

### Lock Screen Accessory Rectangular

Two variants:

- shift-focused: today’s effective shift and schedule label;
- remaining-focused: open activity count and next activity.

Purpose: quick glance on the Lock Screen.

## Interaction

The first implementation should include interactivity, not just static widgets.

The medium widget will expose completion buttons through App Intents. Tapping a check action marks the selected activity completed, writes to shared storage, and lets WidgetKit reload the widget timeline.

If a widget is locked or the system cannot run the interaction, it still displays the latest known state and opens Dayflow through deep link when tapped.

## Data Architecture

Widgets run in a separate extension process, so the app and widget need shared data access.

The storage layer will move from plain `UserDefaults.standard` to an App Group-backed UserDefaults suite. The shared group should be:

`group.com.dayflow.app`

The existing `DayActivityStorage` abstraction stays. A shared storage implementation will load and save the same activities, day details, and shift schedule for both the app target and widget extension.

Migration requirement: on first app launch after the change, if shared storage is empty and legacy standard UserDefaults contains Dayflow data, copy legacy data into the shared suite so existing user data is not lost.

## Visual Rules

Widgets should follow the approved Dayflow style:

- black or near-black backgrounds;
- lime for primary progress and active state;
- rose only for night/alert emphasis;
- Unbounded for major numbers and labels;
- Manrope for smaller metadata;
- rounded but controlled corners;
- no explanatory marketing text inside widgets;
- no generic card stacks or light iOS template styling;
- use WidgetKit-safe SwiftUI layouts with stable dimensions.

Alignment cleanup during implementation:

- center percentages and rings exactly;
- align task rows on a consistent grid;
- keep small widget text inside safe margins;
- avoid text clipping with Russian strings;
- verify small, medium, large, and Lock Screen sizes in previews/build.

## App Integration

The main app does not need a new visible tab for widgets.

Settings can optionally show a small “Виджеты” row later, but the initial widget release should rely on the native system widget gallery. This keeps the feature Apple-native and avoids unnecessary UI.

Deep links should open Dayflow to the most relevant screen:

- plan widgets open Home;
- shift widgets open Calendar;
- weekly pulse opens Statistics.

Deep link routing can be added after the widget target compiles and shares data correctly.

## Testing

Core tests should cover:

- shared storage reads the same data as app storage;
- migration from standard UserDefaults to App Group storage;
- widget snapshot model for today returns real summary, next activities, shift, and weekly stats;
- completion intent marks the correct activity completed;
- completion intent is idempotent for already-completed activities.

Build verification:

- `swift test`
- `xcodebuild -quiet build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- build widget extension target as part of the app scheme

## Implementation Notes

The project currently uses a manually maintained `.xcodeproj`. Adding a widget extension means updating:

- `Dayflow.xcodeproj/project.pbxproj`
- widget source files
- widget `Info.plist`
- app and widget entitlements
- shared App Group identifier
- target dependencies and embed app extensions phase

Because this is a native extension, implementation should be incremental:

1. shared storage and migration;
2. widget snapshot model with tests;
3. widget extension target and static widget views;
4. AppIntent completion action;
5. visual alignment pass and build verification.
