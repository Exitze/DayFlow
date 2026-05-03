import Foundation

public enum DayActivityCategory: String, Codable, CaseIterable, Equatable, Identifiable {
    case all
    case personal
    case body

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return "Все"
        case .personal:
            return "Личное"
        case .body:
            return "Тело"
        }
    }
}

public enum ActivityAccent: String, Codable, CaseIterable, Equatable {
    case lime
    case sky
    case rose
}

public enum ShiftKind: String, Codable, CaseIterable, Equatable, Identifiable {
    case none
    case morning
    case day
    case night
    case recovery
    case rest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none:
            return "Без смены"
        case .morning:
            return "Утро"
        case .day:
            return "День"
        case .night:
            return "Ночь"
        case .recovery:
            return "Отсыпной"
        case .rest:
            return "Выходной"
        }
    }
}

public enum ShiftSchedulePreset: String, Codable, CaseIterable, Equatable, Identifiable {
    case twoTwo
    case twoFive
    case twoDayTwoNight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .twoTwo:
            return "2/2"
        case .twoFive:
            return "2/5"
        case .twoDayTwoNight:
            return "2Д/2Н"
        }
    }

    public var subtitle: String {
        switch self {
        case .twoTwo:
            return "2 рабочих, 2 выходных"
        case .twoFive:
            return "2 рабочих, 5 выходных"
        case .twoDayTwoNight:
            return "2 дня, 2 ночи, отсыпной"
        }
    }

    public var cycle: [ShiftKind] {
        switch self {
        case .twoTwo:
            return [.day, .day, .rest, .rest]
        case .twoFive:
            return [.day, .day, .rest, .rest, .rest, .rest, .rest]
        case .twoDayTwoNight:
            return [.day, .day, .night, .night, .recovery, .rest]
        }
    }
}

public struct ShiftSchedule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var preset: ShiftSchedulePreset
    public var name: String
    public var startDayID: String
    public var cycle: [ShiftKind]
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        preset: ShiftSchedulePreset,
        name: String,
        startDayID: String,
        cycle: [ShiftKind],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.preset = preset
        self.name = name
        self.startDayID = startDayID
        self.cycle = cycle
        self.isEnabled = isEnabled
    }

    public static func makePreset(
        _ preset: ShiftSchedulePreset,
        starting date: Date,
        calendar: Calendar = .current
    ) -> ShiftSchedule {
        ShiftSchedule(
            preset: preset,
            name: preset.title,
            startDayID: DayActivity.dayID(for: date, calendar: calendar),
            cycle: preset.cycle
        )
    }

    public func shift(on date: Date, calendar: Calendar = .current) -> ShiftKind? {
        guard isEnabled,
              !cycle.isEmpty,
              let startDate = Self.date(fromDayID: startDayID, calendar: calendar) else {
            return nil
        }

        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        let cycleIndex = ((dayOffset % cycle.count) + cycle.count) % cycle.count
        return cycle[cycleIndex]
    }

    private static func date(fromDayID dayID: String, calendar: Calendar) -> Date? {
        let parts = dayID.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}

public enum DayActivityValidationError: Error, Equatable {
    case blankTitle
    case invalidTime
    case invalidCategory
    case activityNotFound
}

public struct NewDayActivity: Equatable {
    public var title: String
    public var timeText: String
    public var detail: String
    public var category: DayActivityCategory
    public var icon: String
    public var accent: ActivityAccent
    public var dayID: String?

    public init(
        title: String,
        timeText: String,
        detail: String,
        category: DayActivityCategory,
        icon: String,
        accent: ActivityAccent,
        dayID: String? = nil
    ) {
        self.title = title
        self.timeText = timeText
        self.detail = detail
        self.category = category
        self.icon = icon
        self.accent = accent
        self.dayID = dayID
    }
}

public struct DayActivity: Codable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var timeMinutes: Int
    public var detail: String
    public var category: DayActivityCategory
    public var icon: String
    public var accent: ActivityAccent
    public var isCompleted: Bool
    public var dayID: String?

    public var timeText: String {
        Self.timeText(from: timeMinutes)
    }

    public init(
        id: UUID = UUID(),
        title: String,
        timeMinutes: Int,
        detail: String,
        category: DayActivityCategory,
        icon: String,
        accent: ActivityAccent,
        isCompleted: Bool = false,
        dayID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.timeMinutes = timeMinutes
        self.detail = detail
        self.category = category
        self.icon = icon
        self.accent = accent
        self.isCompleted = isCompleted
        self.dayID = dayID
    }

    public init(_ newActivity: NewDayActivity) throws {
        let title = newActivity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw DayActivityValidationError.blankTitle
        }

        guard newActivity.category != .all else {
            throw DayActivityValidationError.invalidCategory
        }

        guard let timeMinutes = Self.parseTimeText(newActivity.timeText) else {
            throw DayActivityValidationError.invalidTime
        }

        let detail = newActivity.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = newActivity.icon.trimmingCharacters(in: .whitespacesAndNewlines)

        self.init(
            title: title,
            timeMinutes: timeMinutes,
            detail: detail.isEmpty ? "Без деталей" : detail,
            category: newActivity.category,
            icon: icon.isEmpty ? "circle.fill" : icon,
            accent: newActivity.accent,
            dayID: newActivity.dayID
        )
    }

    public static func parseTimeText(_ text: String) -> Int? {
        let parts = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)

        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              (0...23).contains(hours),
              (0...59).contains(minutes) else {
            return nil
        }

        return hours * 60 + minutes
    }

    public static func timeText(from minutes: Int) -> String {
        let hours = max(0, minutes) / 60
        let minute = max(0, minutes) % 60
        return String(format: "%d:%02d", hours, minute)
    }

    public static func sorted(_ activities: [DayActivity]) -> [DayActivity] {
        activities.sorted {
            if $0.timeMinutes == $1.timeMinutes {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

            return $0.timeMinutes < $1.timeMinutes
        }
    }

    public static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public struct DayDetails: Codable, Equatable, Identifiable {
    public var dayID: String
    public var note: String
    public var shift: ShiftKind
    public var hasManualShift: Bool

    public var id: String { dayID }

    public init(dayID: String, note: String = "", shift: ShiftKind = .none, hasManualShift: Bool = false) {
        self.dayID = dayID
        self.note = note
        self.shift = shift
        self.hasManualShift = hasManualShift
    }

    private enum CodingKeys: String, CodingKey {
        case dayID
        case note
        case shift
        case hasManualShift
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dayID = try container.decode(String.self, forKey: .dayID)
        self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.shift = try container.decodeIfPresent(ShiftKind.self, forKey: .shift) ?? .none
        self.hasManualShift = try container.decodeIfPresent(Bool.self, forKey: .hasManualShift) ?? (shift != .none)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayID, forKey: .dayID)
        try container.encode(note, forKey: .note)
        try container.encode(shift, forKey: .shift)
        try container.encode(hasManualShift, forKey: .hasManualShift)
    }
}

public struct DayStatsDay: Equatable, Identifiable {
    public var id: String { dayID }
    public var dayID: String
    public var date: Date
    public var totalCount: Int
    public var completedCount: Int
    public var completionPercent: Int
    public var shift: ShiftKind

    public var isFullyCompleted: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    public init(dayID: String, date: Date, totalCount: Int, completedCount: Int, shift: ShiftKind) {
        self.dayID = dayID
        self.date = date
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.completionPercent = totalCount == 0
            ? 0
            : Int((Double(completedCount) / Double(totalCount) * 100).rounded())
        self.shift = shift
    }
}

public struct DayStatsCategory: Equatable, Identifiable {
    public var id: String { category.rawValue }
    public var category: DayActivityCategory
    public var totalCount: Int
    public var completedCount: Int
    public var completionPercent: Int

    public init(category: DayActivityCategory, activities: [DayActivity]) {
        self.category = category
        self.totalCount = activities.count
        self.completedCount = activities.filter(\.isCompleted).count
        self.completionPercent = activities.isEmpty
            ? 0
            : Int((Double(completedCount) / Double(totalCount) * 100).rounded())
    }
}

public struct DayStatsShift: Equatable, Identifiable {
    public var id: String { shift.rawValue }
    public var shift: ShiftKind
    public var dayCount: Int

    public init(shift: ShiftKind, dayCount: Int) {
        self.shift = shift
        self.dayCount = dayCount
    }
}

public struct DayStatsSummary: Equatable {
    public var days: [DayStatsDay]
    public var categoryStats: [DayStatsCategory]
    public var shiftStats: [DayStatsShift]
    public var totalActivities: Int
    public var completedActivities: Int
    public var completionPercent: Int
    public var activeDays: Int
    public var completedDays: Int
    public var currentCompletionStreak: Int
    public var busiestDay: DayStatsDay?
    public var focusedDay: DayStatsDay? { days.last }

    public init(days: [DayStatsDay], categoryStats: [DayStatsCategory], shiftStats: [DayStatsShift]) {
        self.days = days
        self.categoryStats = categoryStats
        self.shiftStats = shiftStats
        self.totalActivities = days.reduce(0) { $0 + $1.totalCount }
        self.completedActivities = days.reduce(0) { $0 + $1.completedCount }
        self.completionPercent = totalActivities == 0
            ? 0
            : Int((Double(completedActivities) / Double(totalActivities) * 100).rounded())
        self.activeDays = days.filter { $0.totalCount > 0 }.count
        self.completedDays = days.filter(\.isFullyCompleted).count
        self.currentCompletionStreak = days.reversed().prefix { $0.isFullyCompleted }.count
        self.busiestDay = days.max {
            if $0.totalCount == $1.totalCount {
                return $0.completedCount < $1.completedCount
            }

            return $0.totalCount < $1.totalCount
        }.flatMap { $0.totalCount > 0 ? $0 : nil }
    }
}

public struct DayPlanSummary: Equatable {
    public var totalCount: Int
    public var completedCount: Int
    public var progressPercent: Int
    public var firstTimeText: String?
    public var lastTimeText: String?
    public var headline: String

    public init(activities: [DayActivity]) {
        let sortedActivities = DayActivity.sorted(activities)
        let totalCount = sortedActivities.count
        let completedCount = sortedActivities.filter(\.isCompleted).count

        self.totalCount = totalCount
        self.completedCount = completedCount
        self.progressPercent = totalCount == 0
            ? 0
            : Int((Double(completedCount) / Double(totalCount) * 100).rounded())
        self.firstTimeText = sortedActivities.first?.timeText
        self.lastTimeText = sortedActivities.last?.timeText
        self.headline = Self.makeHeadline(count: totalCount)
    }

    private static func makeHeadline(count: Int) -> String {
        guard count > 0 else {
            return "Новый\nдень"
        }

        return "\(count) \(activityWord(for: count))\nдо вечера"
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

public struct AppLegalSection: Equatable, Identifiable {
    public var title: String
    public var body: String

    public var id: String { title }

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public enum AppLegalDocument: String, CaseIterable, Equatable, Identifiable {
    case privacyPolicy
    case terms
    case support

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .privacyPolicy:
            return "Privacy Policy"
        case .terms:
            return "Условия"
        case .support:
            return "Поддержка"
        }
    }

    public var subtitle: String {
        switch self {
        case .privacyPolicy:
            return "официальная политика данных"
        case .terms:
            return "официальные правила использования"
        case .support:
            return "email и публичная страница"
        }
    }

    public var publicURLString: String {
        switch self {
        case .privacyPolicy:
            return "https://exitze.github.io/DayFlow/privacy.html"
        case .terms:
            return "https://exitze.github.io/DayFlow/terms.html"
        case .support:
            return "https://exitze.github.io/DayFlow/support.html"
        }
    }

    public var publicURL: URL {
        URL(string: publicURLString)!
    }

    public var icon: String {
        switch self {
        case .privacyPolicy:
            return "hand.raised.fill"
        case .terms:
            return "doc.text.fill"
        case .support:
            return "lifepreserver.fill"
        }
    }

    public var sections: [AppLegalSection] {
        switch self {
        case .privacyPolicy:
            return [
                AppLegalSection(
                    title: "Официальная ссылка",
                    body: "Веб-версия документа: https://exitze.github.io/DayFlow/privacy.html"
                ),
                AppLegalSection(
                    title: "Коротко",
                    body: "Dayflow хранит активности, заметки, смены, график, настройки и настройки уведомлений только локально на устройстве через UserDefaults. Приложение не отправляет эти данные на сервер, не продает их и не использует трекинг."
                ),
                AppLegalSection(
                    title: "Какие данные есть в приложении",
                    body: "Пользователь сам добавляет названия активностей, время, детали, заметки календаря и смены. Эти данные нужны только для работы главного экрана, календаря, статистики и настроек."
                ),
                AppLegalSection(
                    title: "Удаление данных",
                    body: "Данные можно удалить в настройках Dayflow: очистить выполненные активности, очистить календарные детали или сбросить все локальные данные приложения."
                ),
                AppLegalSection(
                    title: "Уведомления",
                    body: "Если пользователь включает уведомления, Dayflow создает локальные напоминания на устройстве через Apple UserNotifications. Расписание уведомлений строится из локальных активностей и смен и не отправляется на сервер."
                ),
                AppLegalSection(
                    title: "Аккаунты и аналитика",
                    body: "Dayflow не создает аккаунты, не требует входа, не подключает рекламные сети, не использует стороннюю аналитику и не передает данные другим компаниям."
                ),
                AppLegalSection(
                    title: "Контакт",
                    body: "По вопросам конфиденциальности можно написать на Exitze@icloud.com."
                )
            ]
        case .terms:
            return [
                AppLegalSection(
                    title: "Официальная ссылка",
                    body: "Веб-версия документа: https://exitze.github.io/DayFlow/terms.html"
                ),
                AppLegalSection(
                    title: "Использование",
                    body: "Dayflow помогает вести личный план дня, календарь, смены и статистику. Пользователь отвечает за точность данных, которые он сам добавляет в приложение."
                ),
                AppLegalSection(
                    title: "Локальное хранение",
                    body: "Данные находятся на устройстве. При удалении приложения или сбросе локальных данных восстановление может быть невозможно, если пользователь заранее не сделал резервную копию устройства."
                ),
                AppLegalSection(
                    title: "Без медицинских гарантий",
                    body: "Активности, графики и статистика не являются медицинской, финансовой или юридической рекомендацией. Это личный органайзер."
                ),
                AppLegalSection(
                    title: "Контакт",
                    body: "Вопросы по условиям использования можно отправить на Exitze@icloud.com."
                )
            ]
        case .support:
            return [
                AppLegalSection(
                    title: "Официальная ссылка",
                    body: "Веб-версия поддержки: https://exitze.github.io/DayFlow/support.html"
                ),
                AppLegalSection(
                    title: "Контакт поддержки",
                    body: "Email: Exitze@icloud.com. В письме укажите Dayflow, версию iOS, модель iPhone и короткое описание проблемы."
                ),
                AppLegalSection(
                    title: "Что писать в поддержку",
                    body: "Укажи название приложения, версию iOS, модель iPhone и коротко опиши проблему. Если данные были удалены через сброс или удаление приложения, Dayflow не сможет восстановить их с сервера, потому серверного хранения нет."
                ),
                AppLegalSection(
                    title: "Локальные данные",
                    body: "Dayflow хранит данные на устройстве. Если активность, заметка или смена не отображается, сначала проверь выбранный день календаря и текущий фильтр."
                ),
                AppLegalSection(
                    title: "Уведомления",
                    body: "Если напоминания не приходят, проверь разрешение Dayflow в настройках iOS: Settings → Notifications → Dayflow. Уведомления локальные, поэтому серверной доставки или удаленной рассылки нет."
                )
            ]
        }
    }

    public var body: String {
        sections.map { "\($0.title)\n\($0.body)" }.joined(separator: "\n\n")
    }
}
