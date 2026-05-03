import Combine
import Foundation

public protocol DayActivityStorage {
    func loadActivities() throws -> [DayActivity]
    func saveActivities(_ activities: [DayActivity]) throws
    func loadDayDetails() throws -> [DayDetails]
    func saveDayDetails(_ dayDetails: [DayDetails]) throws
    func loadShiftSchedule() throws -> ShiftSchedule?
    func saveShiftSchedule(_ shiftSchedule: ShiftSchedule?) throws
}

public final class UserDefaultsActivityStorage: DayActivityStorage {
    public static let defaultKey = "dayflow.activities.v1"

    private let defaults: UserDefaults
    private let activitiesKey: String
    private let dayDetailsKey: String
    private let shiftScheduleKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, key: String = defaultKey) {
        self.defaults = defaults
        self.activitiesKey = key
        self.dayDetailsKey = "\(key).day-details"
        self.shiftScheduleKey = "\(key).shift-schedule"
    }

    public static func sharedAppGroupStorage(
        appGroupIdentifier: String = DayflowAppGroup.identifier,
        fallbackDefaults: UserDefaults = .standard
    ) -> UserDefaultsActivityStorage {
        UserDefaultsActivityStorage(defaults: UserDefaults(suiteName: appGroupIdentifier) ?? fallbackDefaults)
    }

    public func loadActivities() throws -> [DayActivity] {
        guard let data = defaults.data(forKey: activitiesKey) else {
            return []
        }

        return try decoder.decode([DayActivity].self, from: data)
    }

    public func saveActivities(_ activities: [DayActivity]) throws {
        let data = try encoder.encode(activities)
        defaults.set(data, forKey: activitiesKey)
    }

    public func loadDayDetails() throws -> [DayDetails] {
        guard let data = defaults.data(forKey: dayDetailsKey) else {
            return []
        }

        return try decoder.decode([DayDetails].self, from: data)
    }

    public func saveDayDetails(_ dayDetails: [DayDetails]) throws {
        let data = try encoder.encode(dayDetails)
        defaults.set(data, forKey: dayDetailsKey)
    }

    public func loadShiftSchedule() throws -> ShiftSchedule? {
        guard let data = defaults.data(forKey: shiftScheduleKey) else {
            return nil
        }

        return try decoder.decode(ShiftSchedule.self, from: data)
    }

    public func saveShiftSchedule(_ shiftSchedule: ShiftSchedule?) throws {
        guard let shiftSchedule else {
            defaults.removeObject(forKey: shiftScheduleKey)
            return
        }

        let data = try encoder.encode(shiftSchedule)
        defaults.set(data, forKey: shiftScheduleKey)
    }
}

public enum DayflowAppGroup {
    public static let identifier = "group.com.exitze.dayflow"
}

public enum DayflowCurrentDay {
    public static func refreshed(_ currentDate: Date, using candidateDate: Date, calendar: Calendar = .current) -> Date {
        calendar.isDate(currentDate, inSameDayAs: candidateDate) ? currentDate : candidateDate
    }
}

public enum DayflowStorageMigration {
    @discardableResult
    public static func migrateIfNeeded(from legacyStorage: DayActivityStorage, to sharedStorage: DayActivityStorage) throws -> Bool {
        let sharedActivities = try sharedStorage.loadActivities()
        let sharedDayDetails = try sharedStorage.loadDayDetails()
        let sharedShiftSchedule = try sharedStorage.loadShiftSchedule()

        guard sharedActivities.isEmpty,
              sharedDayDetails.isEmpty,
              sharedShiftSchedule == nil else {
            return false
        }

        let legacyActivities = try legacyStorage.loadActivities()
        let legacyDayDetails = try legacyStorage.loadDayDetails()
        let legacyShiftSchedule = try legacyStorage.loadShiftSchedule()

        guard !legacyActivities.isEmpty || !legacyDayDetails.isEmpty || legacyShiftSchedule != nil else {
            return false
        }

        try sharedStorage.saveActivities(legacyActivities)
        try sharedStorage.saveDayDetails(legacyDayDetails)
        try sharedStorage.saveShiftSchedule(legacyShiftSchedule)
        return true
    }
}

public final class DayPlanStore: ObservableObject {
    @Published public private(set) var activities: [DayActivity]
    @Published public private(set) var dayDetails: [DayDetails]
    @Published public private(set) var shiftSchedule: ShiftSchedule?

    private let storage: DayActivityStorage
    private let calendar: Calendar
    private let todayProvider: () -> Date

    public var summary: DayPlanSummary {
        summary(on: todayProvider())
    }

    public convenience init(
        calendar: Calendar = .current,
        todayProvider: @escaping () -> Date = Date.init
    ) {
        let sharedStorage = UserDefaultsActivityStorage.sharedAppGroupStorage()
        _ = try? DayflowStorageMigration.migrateIfNeeded(
            from: UserDefaultsActivityStorage(defaults: .standard),
            to: sharedStorage
        )

        self.init(storage: sharedStorage, calendar: calendar, todayProvider: todayProvider)
    }

    public init(
        storage: DayActivityStorage,
        calendar: Calendar = .current,
        todayProvider: @escaping () -> Date = Date.init
    ) {
        let loadedActivities = DayActivity.sorted((try? storage.loadActivities()) ?? [])
        let todayDayID = DayActivity.dayID(for: todayProvider(), calendar: calendar)
        let normalizedActivities = Self.normalizedActivities(loadedActivities, fallbackDayID: todayDayID)

        if normalizedActivities != loadedActivities {
            try? storage.saveActivities(normalizedActivities)
        }

        self.storage = storage
        self.calendar = calendar
        self.todayProvider = todayProvider
        self.activities = normalizedActivities
        self.dayDetails = (try? storage.loadDayDetails())?.sorted { $0.dayID < $1.dayID } ?? []
        self.shiftSchedule = try? storage.loadShiftSchedule()
    }

    private static func normalizedActivities(_ activities: [DayActivity], fallbackDayID: String) -> [DayActivity] {
        DayActivity.sorted(activities.map { activity in
            guard activity.dayID == nil else {
                return activity
            }

            var normalizedActivity = activity
            normalizedActivity.dayID = fallbackDayID
            return normalizedActivity
        })
    }

    public func activities(filteredBy filter: DayActivityCategory) -> [DayActivity] {
        activities(on: todayProvider(), filteredBy: filter)
    }

    public func activities(on date: Date, filteredBy filter: DayActivityCategory = .all) -> [DayActivity] {
        let dayID = DayActivity.dayID(for: date, calendar: calendar)
        let todaysID = DayActivity.dayID(for: todayProvider(), calendar: calendar)
        let scopedActivities = activities.filter { activity in
            (activity.dayID ?? todaysID) == dayID
        }

        guard filter != .all else {
            return DayActivity.sorted(scopedActivities)
        }

        return DayActivity.sorted(scopedActivities.filter { $0.category == filter })
    }

    public func summary(on date: Date) -> DayPlanSummary {
        DayPlanSummary(activities: activities(on: date))
    }

    public func statsSummary(endingOn date: Date, dayCount: Int = 7) -> DayStatsSummary {
        let safeDayCount = max(1, dayCount)
        let endDate = calendar.startOfDay(for: date)
        let startDate = calendar.date(byAdding: .day, value: -(safeDayCount - 1), to: endDate) ?? endDate

        return statsSummary(from: startDate, to: endDate)
    }

    public func statsSummary(forMonthContaining date: Date) -> DayStatsSummary {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? monthStart

        return statsSummary(from: monthStart, to: monthEnd)
    }

    public func statsSummary(from startDate: Date, to endDate: Date) -> DayStatsSummary {
        let start = calendar.startOfDay(for: min(startDate, endDate))
        let end = calendar.startOfDay(for: max(startDate, endDate))
        let daySpan = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let dates = (0...max(0, daySpan)).map { offset in
            calendar.date(byAdding: .day, value: offset, to: start) ?? start
        }

        let days = dates.map { date in
            let dayActivities = activities(on: date)
            return DayStatsDay(
                dayID: dayID(for: date),
                date: date,
                totalCount: dayActivities.count,
                completedCount: dayActivities.filter(\.isCompleted).count,
                shift: effectiveShift(for: date)
            )
        }

        let rangeActivities = dates.flatMap { activities(on: $0) }
        let categoryStats = DayActivityCategory.allCases
            .filter { $0 != .all }
            .map { category in
                DayStatsCategory(
                    category: category,
                    activities: rangeActivities.filter { $0.category == category }
                )
            }

        let shiftStats = ShiftKind.allCases.compactMap { shift -> DayStatsShift? in
            guard shift != .none else {
                return nil
            }

            let dayCount = days.filter { $0.shift == shift }.count
            return dayCount > 0 ? DayStatsShift(shift: shift, dayCount: dayCount) : nil
        }

        return DayStatsSummary(days: days, categoryStats: categoryStats, shiftStats: shiftStats)
    }

    public func details(for date: Date) -> DayDetails {
        storedDetails(for: date) ?? DayDetails(dayID: dayID(for: date))
    }

    public func effectiveShift(for date: Date) -> ShiftKind {
        if let details = storedDetails(for: date), details.hasManualShift {
            return details.shift
        }

        return shiftSchedule?.shift(on: date, calendar: calendar) ?? .none
    }

    public func isShiftOverridden(for date: Date) -> Bool {
        storedDetails(for: date)?.hasManualShift == true
    }

    public func add(_ newActivity: NewDayActivity) throws {
        try add(newActivity, on: todayProvider())
    }

    public func add(_ newActivity: NewDayActivity, on date: Date) throws {
        var activity = try DayActivity(newActivity)
        activity.dayID = DayActivity.dayID(for: date, calendar: calendar)
        let nextActivities = DayActivity.sorted(activities + [activity])

        try storage.saveActivities(nextActivities)
        activities = nextActivities
    }

    public func setCompleted(_ id: UUID, _ completed: Bool) throws {
        var nextActivities = activities

        guard let index = nextActivities.firstIndex(where: { $0.id == id }) else {
            throw DayActivityValidationError.activityNotFound
        }

        nextActivities[index].isCompleted = completed
        try storage.saveActivities(nextActivities)
        activities = nextActivities
    }

    public func remove(_ id: UUID) throws {
        let nextActivities = activities.filter { $0.id != id }
        guard nextActivities.count != activities.count else {
            throw DayActivityValidationError.activityNotFound
        }

        try storage.saveActivities(nextActivities)
        activities = nextActivities
    }

    public func clearCompletedActivities() throws {
        let nextActivities = DayActivity.sorted(activities.filter { !$0.isCompleted })
        try storage.saveActivities(nextActivities)
        activities = nextActivities
    }

    public func clearCalendarDetails() throws {
        try storage.saveDayDetails([])
        dayDetails = []
    }

    public func resetAllData() throws {
        try storage.saveActivities([])
        try storage.saveDayDetails([])
        try storage.saveShiftSchedule(nil)
        activities = []
        dayDetails = []
        shiftSchedule = nil
    }

    public func setNote(_ note: String, for date: Date) throws {
        var details = storedDetails(for: date) ?? DayDetails(dayID: dayID(for: date))
        details.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try saveOrRemove(details)
    }

    public func setShift(_ shift: ShiftKind, for date: Date) throws {
        var details = storedDetails(for: date) ?? DayDetails(dayID: dayID(for: date))
        details.shift = shift
        details.hasManualShift = true
        try save(details)
    }

    public func clearShiftOverride(for date: Date) throws {
        guard var details = storedDetails(for: date), details.hasManualShift else {
            return
        }

        details.shift = .none
        details.hasManualShift = false
        try saveOrRemove(details)
    }

    public func setShiftSchedule(_ shiftSchedule: ShiftSchedule) throws {
        try storage.saveShiftSchedule(shiftSchedule)
        self.shiftSchedule = shiftSchedule
    }

    public func clearShiftSchedule() throws {
        try storage.saveShiftSchedule(nil)
        shiftSchedule = nil
    }

    private func save(_ details: DayDetails) throws {
        var nextDayDetails = dayDetails.filter { $0.dayID != details.dayID }
        nextDayDetails.append(details)
        nextDayDetails.sort { $0.dayID < $1.dayID }

        try storage.saveDayDetails(nextDayDetails)
        dayDetails = nextDayDetails
    }

    private func saveOrRemove(_ details: DayDetails) throws {
        if details.note.isEmpty && !details.hasManualShift {
            try removeDetails(for: details.dayID)
        } else {
            try save(details)
        }
    }

    private func removeDetails(for dayID: String) throws {
        let nextDayDetails = dayDetails.filter { $0.dayID != dayID }
        try storage.saveDayDetails(nextDayDetails)
        dayDetails = nextDayDetails
    }

    private func storedDetails(for date: Date) -> DayDetails? {
        let dayID = dayID(for: date)
        return dayDetails.first { $0.dayID == dayID }
    }

    private func dayID(for date: Date) -> String {
        DayActivity.dayID(for: date, calendar: calendar)
    }
}
