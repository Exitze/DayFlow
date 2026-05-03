# Dayflow Local Notifications

## Goal

Add native iOS local notifications that feel like part of Dayflow and are driven by real planner data.

## Scope

- Morning plan reminder built from today's activities and shift.
- Activity reminders before real scheduled activities.
- Shift reminder for tomorrow, including automatic schedule and manual overrides.
- Evening review reminder based on open activities.
- Home bell opens notification controls.
- Profile/settings include notification status and entry point.
- Privacy/support text mentions optional on-device notifications.

## Non-goals

- Remote push notifications, APNs, a backend server, or marketing broadcasts.
- Fully custom notification UI. iOS owns the notification shell in v1.
- Notification Content Extension. This can come later if richer Lock Screen layouts are needed.

## Behavior

Notifications are opt-in. Dayflow asks for permission only when the user enables reminders or taps the bell settings, not on first launch.

The scheduler replaces only Dayflow pending notifications and never touches unrelated system/app notifications. Generated requests are capped to keep within iOS pending notification limits.

