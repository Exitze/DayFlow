import Foundation

public enum DayflowNotificationKind: String, Codable, Equatable {
    case morningPlan
    case activityReminder
    case shiftReminder
    case eveningReview
}

public struct DayflowNotificationSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var morningPlanEnabled: Bool
    public var activityRemindersEnabled: Bool
    public var shiftReminderEnabled: Bool
    public var eveningReviewEnabled: Bool
    public var morningMinutes: Int
    public var activityLeadMinutes: Int
    public var shiftReminderMinutes: Int
    public var eveningMinutes: Int

    public static let defaults = DayflowNotificationSettings()

    public init(
        isEnabled: Bool = false,
        morningPlanEnabled: Bool = true,
        activityRemindersEnabled: Bool = true,
        shiftReminderEnabled: Bool = true,
        eveningReviewEnabled: Bool = true,
        morningMinutes: Int = 8 * 60 + 30,
        activityLeadMinutes: Int = 15,
        shiftReminderMinutes: Int = 19 * 60,
        eveningMinutes: Int = 21 * 60 + 30
    ) {
        self.isEnabled = isEnabled
        self.morningPlanEnabled = morningPlanEnabled
        self.activityRemindersEnabled = activityRemindersEnabled
        self.shiftReminderEnabled = shiftReminderEnabled
        self.eveningReviewEnabled = eveningReviewEnabled
        self.morningMinutes = Self.clampDayMinutes(morningMinutes)
        self.activityLeadMinutes = max(1, min(180, activityLeadMinutes))
        self.shiftReminderMinutes = Self.clampDayMinutes(shiftReminderMinutes)
        self.eveningMinutes = Self.clampDayMinutes(eveningMinutes)
    }

    private static func clampDayMinutes(_ minutes: Int) -> Int {
        max(0, min(23 * 60 + 59, minutes))
    }
}

public struct DayflowNotificationRequestSpec: Equatable, Identifiable {
    public var id: String
    public var title: String
    public var body: String
    public var date: Date
    public var kind: DayflowNotificationKind
    public var userInfo: [String: String]

    public init(
        id: String,
        title: String,
        body: String,
        date: Date,
        kind: DayflowNotificationKind,
        userInfo: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.kind = kind
        self.userInfo = userInfo
    }
}

public final class UserDefaultsNotificationSettingsStorage {
    public static let defaultKey = "dayflow.notifications.settings.v1"

    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public static func sharedAppGroupStorage(
        appGroupIdentifier: String = DayflowAppGroup.identifier,
        fallbackDefaults: UserDefaults = .standard
    ) -> UserDefaultsNotificationSettingsStorage {
        UserDefaultsNotificationSettingsStorage(defaults: UserDefaults(suiteName: appGroupIdentifier) ?? fallbackDefaults)
    }

    public func load() -> DayflowNotificationSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? decoder.decode(DayflowNotificationSettings.self, from: data) else {
            return .defaults
        }

        return settings
    }

    public func save(_ settings: DayflowNotificationSettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

public enum DayflowNotificationPlanBuilder {
    public static let identifierPrefix = "dayflow.notification"
    public static let maxPendingRequests = 48

    public static func makePlan(
        settings: DayflowNotificationSettings,
        activities: [DayActivity],
        dayDetails: [DayDetails],
        shiftSchedule: ShiftSchedule?,
        now: Date,
        calendar: Calendar = .current,
        dayCount: Int = 7
    ) -> [DayflowNotificationRequestSpec] {
        guard settings.isEnabled else {
            return []
        }

        let safeDayCount = max(1, dayCount)
        let today = calendar.startOfDay(for: now)
        let todayID = DayActivity.dayID(for: today, calendar: calendar)
        let sortedActivities = DayActivity.sorted(activities)
        var requests: [DayflowNotificationRequestSpec] = []

        for offset in 0..<safeDayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }

            let dayID = DayActivity.dayID(for: date, calendar: calendar)
            let dayActivities = activitiesForDay(
                date,
                todayID: todayID,
                activities: sortedActivities,
                calendar: calendar
            )

            if settings.morningPlanEnabled,
               let request = makeMorningRequest(
                for: date,
                dayID: dayID,
                activities: dayActivities,
                shift: effectiveShift(for: date, dayDetails: dayDetails, shiftSchedule: shiftSchedule, calendar: calendar),
                scheduleName: shiftSchedule?.name,
                settings: settings,
                now: now,
                calendar: calendar
               ) {
                requests.append(request)
            }

            if settings.activityRemindersEnabled {
                requests.append(contentsOf: makeActivityRequests(
                    for: date,
                    dayID: dayID,
                    activities: dayActivities,
                    settings: settings,
                    now: now,
                    calendar: calendar
                ))
            }

            if settings.eveningReviewEnabled,
               let request = makeEveningRequest(
                for: date,
                dayID: dayID,
                activities: dayActivities,
                settings: settings,
                now: now,
                calendar: calendar
               ) {
                requests.append(request)
            }

            if settings.shiftReminderEnabled,
               let request = makeShiftRequest(
                on: date,
                dayID: dayID,
                dayDetails: dayDetails,
                shiftSchedule: shiftSchedule,
                settings: settings,
                now: now,
                calendar: calendar
               ) {
                requests.append(request)
            }
        }

        return requests
            .sorted { $0.date < $1.date }
            .prefix(maxPendingRequests)
            .map { $0 }
    }

    private static func makeMorningRequest(
        for date: Date,
        dayID: String,
        activities: [DayActivity],
        shift: ShiftKind,
        scheduleName: String?,
        settings: DayflowNotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> DayflowNotificationRequestSpec? {
        let fireDate = dateBySetting(settings.morningMinutes, on: date, calendar: calendar)
        guard fireDate > now else {
            return nil
        }

        let activityText: String
        if activities.isEmpty {
            activityText = "План пустой. Можно спокойно собрать день."
        } else {
            let titles = activities.prefix(2).map(\.title).joined(separator: ", ")
            activityText = "\(activities.count) \(activityWord(for: activities.count)): \(titles)"
        }

        var pieces = [activityText]
        if shift != .none {
            let shiftText = scheduleName.map { "Смена: \(shift.title) · \($0)" } ?? "Смена: \(shift.title)"
            pieces.append(shiftText)
        }

        return DayflowNotificationRequestSpec(
            id: identifier(kind: .morningPlan, dayID: dayID),
            title: "Dayflow · План дня",
            body: pieces.joined(separator: ". "),
            date: fireDate,
            kind: .morningPlan,
            userInfo: ["kind": DayflowNotificationKind.morningPlan.rawValue, "dayID": dayID]
        )
    }

    private static func makeActivityRequests(
        for date: Date,
        dayID: String,
        activities: [DayActivity],
        settings: DayflowNotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> [DayflowNotificationRequestSpec] {
        activities.compactMap { activity in
            guard !activity.isCompleted else {
                return nil
            }

            let activityDate = dateBySetting(activity.timeMinutes, on: date, calendar: calendar)
            guard let fireDate = calendar.date(byAdding: .minute, value: -settings.activityLeadMinutes, to: activityDate),
                  fireDate > now else {
                return nil
            }

            return DayflowNotificationRequestSpec(
                id: identifier(kind: .activityReminder, dayID: dayID, suffix: activity.id.uuidString),
                title: "\(activity.title) через \(settings.activityLeadMinutes) мин",
                body: "\(activity.detail) · \(activity.timeText)",
                date: fireDate,
                kind: .activityReminder,
                userInfo: [
                    "kind": DayflowNotificationKind.activityReminder.rawValue,
                    "dayID": dayID,
                    "activityID": activity.id.uuidString
                ]
            )
        }
    }

    private static func makeShiftRequest(
        on reminderDate: Date,
        dayID: String,
        dayDetails: [DayDetails],
        shiftSchedule: ShiftSchedule?,
        settings: DayflowNotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> DayflowNotificationRequestSpec? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: reminderDate) else {
            return nil
        }

        let shift = effectiveShift(for: tomorrow, dayDetails: dayDetails, shiftSchedule: shiftSchedule, calendar: calendar)
        guard shift != .none else {
            return nil
        }

        let fireDate = dateBySetting(settings.shiftReminderMinutes, on: reminderDate, calendar: calendar)
        guard fireDate > now else {
            return nil
        }

        let tomorrowID = DayActivity.dayID(for: tomorrow, calendar: calendar)
        let scheduleText = shiftSchedule?.name ?? "ручной график"

        return DayflowNotificationRequestSpec(
            id: identifier(kind: .shiftReminder, dayID: dayID),
            title: "Завтра: \(shift.title)",
            body: "Смена: \(shift.title). График \(scheduleText). Проверь план на завтра.",
            date: fireDate,
            kind: .shiftReminder,
            userInfo: [
                "kind": DayflowNotificationKind.shiftReminder.rawValue,
                "dayID": tomorrowID
            ]
        )
    }

    private static func makeEveningRequest(
        for date: Date,
        dayID: String,
        activities: [DayActivity],
        settings: DayflowNotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> DayflowNotificationRequestSpec? {
        let fireDate = dateBySetting(settings.eveningMinutes, on: date, calendar: calendar)
        guard fireDate > now else {
            return nil
        }

        let openActivities = activities.filter { !$0.isCompleted }
        let body: String
        if openActivities.isEmpty {
            body = activities.isEmpty
                ? "День свободный. Можно закрыть без долгов."
                : "Все закрыто. День можно спокойно завершить."
        } else {
            let titles = openActivities.prefix(2).map(\.title).joined(separator: ", ")
            body = "\(openActivities.count) открыто: \(titles)"
        }

        return DayflowNotificationRequestSpec(
            id: identifier(kind: .eveningReview, dayID: dayID),
            title: "Dayflow · Закрыть день",
            body: body,
            date: fireDate,
            kind: .eveningReview,
            userInfo: ["kind": DayflowNotificationKind.eveningReview.rawValue, "dayID": dayID]
        )
    }

    private static func activitiesForDay(
        _ date: Date,
        todayID: String,
        activities: [DayActivity],
        calendar: Calendar
    ) -> [DayActivity] {
        let dayID = DayActivity.dayID(for: date, calendar: calendar)
        return activities.filter { activity in
            (activity.dayID ?? todayID) == dayID
        }
    }

    private static func effectiveShift(
        for date: Date,
        dayDetails: [DayDetails],
        shiftSchedule: ShiftSchedule?,
        calendar: Calendar
    ) -> ShiftKind {
        let dayID = DayActivity.dayID(for: date, calendar: calendar)
        if let details = dayDetails.first(where: { $0.dayID == dayID }), details.hasManualShift {
            return details.shift
        }

        return shiftSchedule?.shift(on: date, calendar: calendar) ?? .none
    }

    private static func dateBySetting(_ minutes: Int, on date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: max(0, min(23 * 60 + 59, minutes)), to: start) ?? start
    }

    private static func identifier(kind: DayflowNotificationKind, dayID: String, suffix: String? = nil) -> String {
        let base = "\(identifierPrefix).\(kind.rawValue).\(dayID)"
        return suffix.map { "\(base).\($0)" } ?? base
    }

    private static func activityWord(for count: Int) -> String {
        let lastTwoDigits = count % 100
        if (11...14).contains(lastTwoDigits) {
            return "дел"
        }

        switch count % 10 {
        case 1:
            return "дело"
        case 2...4:
            return "дела"
        default:
            return "дел"
        }
    }
}
