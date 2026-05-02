import Foundation

public struct DayflowWidgetActivitySnapshot: Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var timeText: String
    public var icon: String
    public var accent: ActivityAccent
    public var isCompleted: Bool

    public init(activity: DayActivity) {
        self.id = activity.id
        self.title = activity.title
        self.timeText = activity.timeText
        self.icon = activity.icon
        self.accent = activity.accent
        self.isCompleted = activity.isCompleted
    }
}

public struct DayflowWidgetDayPulse: Equatable, Identifiable {
    public var id: String { dayID }
    public var dayID: String
    public var date: Date
    public var totalCount: Int
    public var completedCount: Int
    public var completionPercent: Int
    public var shift: ShiftKind

    public init(day: DayStatsDay) {
        self.dayID = day.dayID
        self.date = day.date
        self.totalCount = day.totalCount
        self.completedCount = day.completedCount
        self.completionPercent = day.completionPercent
        self.shift = day.shift
    }
}

public struct DayflowWidgetSnapshot: Equatable {
    public var date: Date
    public var totalCount: Int
    public var completedCount: Int
    public var progressPercent: Int
    public var nextActivities: [DayflowWidgetActivitySnapshot]
    public var effectiveShift: ShiftKind
    public var scheduleName: String?
    public var weekDays: [DayflowWidgetDayPulse]

    public init(
        date: Date,
        totalCount: Int,
        completedCount: Int,
        progressPercent: Int,
        nextActivities: [DayflowWidgetActivitySnapshot],
        effectiveShift: ShiftKind,
        scheduleName: String?,
        weekDays: [DayflowWidgetDayPulse]
    ) {
        self.date = date
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.progressPercent = progressPercent
        self.nextActivities = nextActivities
        self.effectiveShift = effectiveShift
        self.scheduleName = scheduleName
        self.weekDays = weekDays
    }
}

public enum DayflowWidgetSnapshotBuilder {
    public static func snapshot(
        on date: Date = Date(),
        storage: DayActivityStorage = UserDefaultsActivityStorage.sharedAppGroupStorage(),
        calendar: Calendar = .current
    ) -> DayflowWidgetSnapshot {
        let store = DayPlanStore(storage: storage, calendar: calendar, todayProvider: { date })
        let summary = store.summary(on: date)
        let nextActivities = store.activities(on: date)
            .filter { !$0.isCompleted }
            .prefix(3)
            .map(DayflowWidgetActivitySnapshot.init(activity:))
        let week = store.statsSummary(endingOn: date)

        return DayflowWidgetSnapshot(
            date: date,
            totalCount: summary.totalCount,
            completedCount: summary.completedCount,
            progressPercent: summary.progressPercent,
            nextActivities: Array(nextActivities),
            effectiveShift: store.effectiveShift(for: date),
            scheduleName: store.shiftSchedule?.name,
            weekDays: week.days.map(DayflowWidgetDayPulse.init(day:))
        )
    }
}

public enum DayflowWidgetActionService {
    @discardableResult
    public static func completeActivity(
        id: UUID,
        storage: DayActivityStorage = UserDefaultsActivityStorage.sharedAppGroupStorage(),
        calendar: Calendar = .current,
        todayProvider: @escaping () -> Date = Date.init
    ) throws -> Bool {
        let store = DayPlanStore(storage: storage, calendar: calendar, todayProvider: todayProvider)

        guard let activity = store.activities.first(where: { $0.id == id }) else {
            return false
        }

        guard !activity.isCompleted else {
            return false
        }

        try store.setCompleted(id, true)
        return true
    }
}
