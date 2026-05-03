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
    case dayNightRest
    case fiveTwo
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .twoTwo:
            return "2/2"
        case .twoFive:
            return "2/5"
        case .twoDayTwoNight:
            return "2Д/2Н"
        case .dayNightRest:
            return "День/Ночь"
        case .fiveTwo:
            return "5/2"
        case .custom:
            return "Свой"
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
        case .dayNightRest:
            return "день, ночь, отсыпной, выходной"
        case .fiveTwo:
            return "5 рабочих, 2 выходных"
        case .custom:
            return "формула пользователя"
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
        case .dayNightRest:
            return [.day, .night, .recovery, .rest]
        case .fiveTwo:
            return [.day, .day, .day, .day, .day, .rest, .rest]
        case .custom:
            return []
        }
    }
}

public enum ShiftScheduleValidationError: Error, Equatable {
    case emptyCycle
}

public struct ShiftPaySettings: Codable, Equatable {
    public var startMinutes: Int
    public var endMinutes: Int
    public var hourlyRate: Double
    public var payMultiplier: Double
    public var overtimeThresholdMinutes: Int
    public var overtimeMultiplier: Double

    public init(
        startMinutes: Int,
        endMinutes: Int,
        hourlyRate: Double,
        payMultiplier: Double = 1,
        overtimeThresholdMinutes: Int = 8 * 60,
        overtimeMultiplier: Double = 1.5
    ) {
        self.startMinutes = Self.clampMinutes(startMinutes)
        self.endMinutes = Self.clampMinutes(endMinutes)
        self.hourlyRate = max(0, hourlyRate)
        self.payMultiplier = max(0, payMultiplier)
        self.overtimeThresholdMinutes = max(0, overtimeThresholdMinutes)
        self.overtimeMultiplier = max(0, overtimeMultiplier)
    }

    public var durationMinutes: Int {
        if startMinutes == endMinutes {
            return 0
        }

        if endMinutes > startMinutes {
            return endMinutes - startMinutes
        }

        return (24 * 60 - startMinutes) + endMinutes
    }

    public var startTimeText: String {
        DayActivity.timeText(from: startMinutes)
    }

    public var endTimeText: String {
        DayActivity.timeText(from: endMinutes)
    }

    public static func defaultSettings(for shift: ShiftKind) -> ShiftPaySettings {
        switch shift {
        case .none, .recovery, .rest:
            return ShiftPaySettings(startMinutes: 0, endMinutes: 0, hourlyRate: 0)
        case .morning:
            return ShiftPaySettings(startMinutes: 6 * 60, endMinutes: 14 * 60, hourlyRate: 0)
        case .day:
            return ShiftPaySettings(startMinutes: 8 * 60, endMinutes: 20 * 60, hourlyRate: 0)
        case .night:
            return ShiftPaySettings(startMinutes: 20 * 60, endMinutes: 8 * 60, hourlyRate: 0, payMultiplier: 1.2)
        }
    }

    public static func defaultScheduleSettings() -> [ShiftKind: ShiftPaySettings] {
        Dictionary(uniqueKeysWithValues: ShiftKind.allCases.map { ($0, defaultSettings(for: $0)) })
    }

    private static func clampMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 0), 23 * 60 + 59)
    }
}

public struct ShiftScheduleFormula: Codable, Equatable {
    public var dayCount: Int
    public var nightCount: Int
    public var recoveryCount: Int
    public var restCount: Int

    public init(dayCount: Int, nightCount: Int, recoveryCount: Int, restCount: Int) {
        self.dayCount = Self.clamped(dayCount)
        self.nightCount = Self.clamped(nightCount)
        self.recoveryCount = Self.clamped(recoveryCount)
        self.restCount = Self.clamped(restCount)
    }

    public var cycle: [ShiftKind] {
        Array(repeating: .day, count: dayCount)
            + Array(repeating: .night, count: nightCount)
            + Array(repeating: .recovery, count: recoveryCount)
            + Array(repeating: .rest, count: restCount)
    }

    public var title: String {
        let parts = [
            titlePart(count: dayCount, symbol: "Д"),
            titlePart(count: nightCount, symbol: "Н"),
            titlePart(count: recoveryCount, symbol: "О"),
            titlePart(count: restCount, symbol: "В")
        ].compactMap { $0 }

        return parts.isEmpty ? "Пустой график" : parts.joined(separator: " · ")
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 0), 31)
    }

    private func titlePart(count: Int, symbol: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count)\(symbol)"
    }
}

public struct ShiftSchedule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var preset: ShiftSchedulePreset
    public var name: String
    public var startDayID: String
    public var cycle: [ShiftKind]
    public var isEnabled: Bool
    public var paySettings: [ShiftKind: ShiftPaySettings]

    public init(
        id: UUID = UUID(),
        preset: ShiftSchedulePreset,
        name: String,
        startDayID: String,
        cycle: [ShiftKind],
        isEnabled: Bool = true,
        paySettings: [ShiftKind: ShiftPaySettings] = ShiftPaySettings.defaultScheduleSettings()
    ) {
        self.id = id
        self.preset = preset
        self.name = name
        self.startDayID = startDayID
        self.cycle = cycle
        self.isEnabled = isEnabled
        self.paySettings = paySettings
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case preset
        case name
        case startDayID
        case cycle
        case isEnabled
        case paySettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.preset = try container.decode(ShiftSchedulePreset.self, forKey: .preset)
        self.name = try container.decode(String.self, forKey: .name)
        self.startDayID = try container.decode(String.self, forKey: .startDayID)
        self.cycle = try container.decode([ShiftKind].self, forKey: .cycle)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.paySettings = try container.decodeIfPresent([ShiftKind: ShiftPaySettings].self, forKey: .paySettings)
            ?? ShiftPaySettings.defaultScheduleSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(preset, forKey: .preset)
        try container.encode(name, forKey: .name)
        try container.encode(startDayID, forKey: .startDayID)
        try container.encode(cycle, forKey: .cycle)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(paySettings, forKey: .paySettings)
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

    public static func makeCustom(
        formula: ShiftScheduleFormula,
        starting date: Date,
        calendar: Calendar = .current
    ) throws -> ShiftSchedule {
        let cycle = formula.cycle
        guard !cycle.isEmpty else {
            throw ShiftScheduleValidationError.emptyCycle
        }

        return ShiftSchedule(
            preset: .custom,
            name: formula.title,
            startDayID: DayActivity.dayID(for: date, calendar: calendar),
            cycle: cycle
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

    public func paySettings(for shift: ShiftKind) -> ShiftPaySettings {
        var settings = paySettings[shift] ?? ShiftPaySettings.defaultSettings(for: shift)
        if [.morning, .night].contains(shift),
           settings.hourlyRate == 0,
           let daySettings = paySettings[.day],
           daySettings.hourlyRate > 0 {
            settings.hourlyRate = daySettings.hourlyRate
        }
        return settings
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

public enum DayflowOnboardingScenario: String, Codable, CaseIterable, Equatable, Identifiable {
    case shifts
    case body
    case focus
    case simple

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .shifts:
            return "Сменный график"
        case .body:
            return "Спорт и рутина"
        case .focus:
            return "Фокус и дела"
        case .simple:
            return "Простой план дня"
        }
    }

    public var subtitle: String {
        switch self {
        case .shifts:
            return "Собери день вокруг работы, ночей и восстановления."
        case .body:
            return "Тренировки, сон, вода и ежедневная дисциплина."
        case .focus:
            return "Меньше шума, больше важных личных задач."
        case .simple:
            return "Лёгкий старт без сложных настроек."
        }
    }

    public var icon: String {
        switch self {
        case .shifts:
            return "calendar.badge.clock"
        case .body:
            return "figure.run"
        case .focus:
            return "target"
        case .simple:
            return "sparkles"
        }
    }
}

public struct DayflowOnboardingActivityTemplate: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var timeText: String
    public var detail: String
    public var category: DayActivityCategory
    public var icon: String
    public var accent: ActivityAccent

    public init(
        id: String,
        title: String,
        timeText: String,
        detail: String,
        category: DayActivityCategory,
        icon: String,
        accent: ActivityAccent
    ) {
        self.id = id
        self.title = title
        self.timeText = timeText
        self.detail = detail
        self.category = category
        self.icon = icon
        self.accent = accent
    }

    public var newActivity: NewDayActivity {
        NewDayActivity(
            title: title,
            timeText: timeText,
            detail: detail,
            category: category,
            icon: icon,
            accent: accent
        )
    }
}

public struct DayflowOnboardingPlan: Codable, Equatable {
    public var scenario: DayflowOnboardingScenario
    public var shiftPreset: ShiftSchedulePreset?
    public var selectedTemplateIDs: [String]

    public init(
        scenario: DayflowOnboardingScenario,
        shiftPreset: ShiftSchedulePreset? = nil,
        selectedTemplateIDs: [String]
    ) {
        self.scenario = scenario
        self.shiftPreset = shiftPreset
        self.selectedTemplateIDs = selectedTemplateIDs
    }
}

public enum DayflowOnboardingCatalog {
    public static let templates: [DayflowOnboardingActivityTemplate] = [
        DayflowOnboardingActivityTemplate(
            id: "work",
            title: "Работа",
            timeText: "9:00",
            detail: "Смена или основной рабочий блок",
            category: .personal,
            icon: "briefcase.fill",
            accent: .lime
        ),
        DayflowOnboardingActivityTemplate(
            id: "sleep",
            title: "Сон",
            timeText: "23:00",
            detail: "Восстановление и режим",
            category: .body,
            icon: "bed.double.fill",
            accent: .rose
        ),
        DayflowOnboardingActivityTemplate(
            id: "water",
            title: "Вода",
            timeText: "10:00",
            detail: "Не забыть пить воду",
            category: .body,
            icon: "drop.fill",
            accent: .sky
        ),
        DayflowOnboardingActivityTemplate(
            id: "gym",
            title: "Зал",
            timeText: "20:00",
            detail: "Силовая тренировка",
            category: .body,
            icon: "dumbbell.fill",
            accent: .lime
        ),
        DayflowOnboardingActivityTemplate(
            id: "run",
            title: "Бег",
            timeText: "7:00",
            detail: "Парк или дорожка",
            category: .body,
            icon: "figure.run",
            accent: .sky
        ),
        DayflowOnboardingActivityTemplate(
            id: "meditation",
            title: "Медитация",
            timeText: "22:00",
            detail: "15 минут тишины",
            category: .personal,
            icon: "moon.fill",
            accent: .rose
        ),
        DayflowOnboardingActivityTemplate(
            id: "study",
            title: "Учёба",
            timeText: "18:00",
            detail: "Фокус-блок без отвлечений",
            category: .personal,
            icon: "book.closed.fill",
            accent: .lime
        ),
        DayflowOnboardingActivityTemplate(
            id: "walk",
            title: "Прогулка",
            timeText: "19:00",
            detail: "Разгрузить голову",
            category: .body,
            icon: "figure.walk",
            accent: .sky
        ),
        DayflowOnboardingActivityTemplate(
            id: "reading",
            title: "Чтение",
            timeText: "21:30",
            detail: "Книга или конспект",
            category: .personal,
            icon: "text.book.closed.fill",
            accent: .lime
        ),
        DayflowOnboardingActivityTemplate(
            id: "stretch",
            title: "Растяжка",
            timeText: "8:30",
            detail: "10 минут для тела",
            category: .body,
            icon: "figure.flexibility",
            accent: .rose
        )
    ]

    public static func recommendedTemplates(for scenario: DayflowOnboardingScenario) -> [DayflowOnboardingActivityTemplate] {
        templateIDs(for: scenario).compactMap(template)
    }

    public static func template(id: String) -> DayflowOnboardingActivityTemplate? {
        templates.first { $0.id == id }
    }

    private static func templateIDs(for scenario: DayflowOnboardingScenario) -> [String] {
        switch scenario {
        case .shifts:
            return ["work", "sleep", "water", "gym", "run", "meditation"]
        case .body:
            return ["run", "gym", "water", "sleep", "walk", "stretch"]
        case .focus:
            return ["study", "meditation", "reading", "walk", "water", "sleep"]
        case .simple:
            return ["work", "water", "walk", "reading", "meditation", "sleep"]
        }
    }
}

public enum DayflowOnboardingBuilder {
    public static func makeActivities(from plan: DayflowOnboardingPlan) -> [NewDayActivity] {
        var seenIDs = Set<String>()

        return plan.selectedTemplateIDs.compactMap { templateID in
            guard seenIDs.insert(templateID).inserted,
                  let template = DayflowOnboardingCatalog.template(id: templateID) else {
                return nil
            }

            return template.newActivity
        }
    }

    public static func makeShiftSchedule(
        from plan: DayflowOnboardingPlan,
        starting date: Date,
        calendar: Calendar = .current
    ) -> ShiftSchedule? {
        guard let shiftPreset = plan.shiftPreset else {
            return nil
        }

        return ShiftSchedule.makePreset(shiftPreset, starting: date, calendar: calendar)
    }
}

public enum DayActivityValidationError: Error, Equatable {
    case blankTitle
    case invalidTime
    case invalidCategory
    case activityNotFound
    case invalidRecurrence
    case invalidHabitGoal
}

public struct DayflowQuickActivityTemplate: Equatable, Identifiable {
    public var id: String
    public var title: String
    public var timeText: String
    public var detail: String
    public var category: DayActivityCategory
    public var icon: String
    public var accent: ActivityAccent
    public var aliases: [String]

    public var newActivity: NewDayActivity {
        NewDayActivity(
            title: title,
            timeText: timeText,
            detail: detail,
            category: category,
            icon: icon,
            accent: accent
        )
    }
}

public enum DayflowQuickActivityCatalog {
    public static let templates: [DayflowQuickActivityTemplate] = [
        DayflowQuickActivityTemplate(
            id: "run",
            title: "Бег",
            timeText: "7:00",
            detail: "Парк или дорожка",
            category: .body,
            icon: "figure.run",
            accent: .sky,
            aliases: ["бег", "пробежка", "run", "running"]
        ),
        DayflowQuickActivityTemplate(
            id: "gym",
            title: "Зал",
            timeText: "20:00",
            detail: "Силовая тренировка",
            category: .body,
            icon: "dumbbell.fill",
            accent: .lime,
            aliases: ["зал", "тренировка", "качалка", "gym"]
        ),
        DayflowQuickActivityTemplate(
            id: "water",
            title: "Вода",
            timeText: "10:00",
            detail: "Стакан воды",
            category: .body,
            icon: "drop.fill",
            accent: .sky,
            aliases: ["вода", "water", "пить воду"]
        ),
        DayflowQuickActivityTemplate(
            id: "sleep",
            title: "Сон",
            timeText: "23:00",
            detail: "Лечь без телефона",
            category: .personal,
            icon: "bed.double.fill",
            accent: .rose,
            aliases: ["сон", "спать", "sleep"]
        ),
        DayflowQuickActivityTemplate(
            id: "work",
            title: "Работа",
            timeText: "9:00",
            detail: "Главный рабочий блок",
            category: .personal,
            icon: "briefcase.fill",
            accent: .lime,
            aliases: ["работа", "смена", "work"]
        ),
        DayflowQuickActivityTemplate(
            id: "meditation",
            title: "Медитация",
            timeText: "22:00",
            detail: "15 минут тишины",
            category: .personal,
            icon: "moon.fill",
            accent: .rose,
            aliases: ["медитация", "медитацию", "meditation", "дыхание"]
        )
    ]

    public static func template(matching text: String) -> DayflowQuickActivityTemplate? {
        let normalizedText = normalized(text)
        return templates.first { template in
            template.aliases.contains { alias in
                normalizedText == normalized(alias)
            }
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
    }
}

public enum DayflowQuickCaptureParser {
    public static func parse(_ text: String, fallbackTimeText: String) throws -> NewDayActivity {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw DayActivityValidationError.blankTitle
        }

        let timeMatch = extractTime(from: trimmedText)
        let titleText = timeMatch.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = DayflowQuickActivityCatalog.template(matching: titleText)
        let rawTitle = template?.title ?? titleText
        let title = titleCased(rawTitle)
        let timeText = timeMatch.timeText ?? template?.timeText ?? fallbackTimeText

        guard DayActivity.parseTimeText(timeText) != nil else {
            throw DayActivityValidationError.invalidTime
        }

        return NewDayActivity(
            title: title,
            timeText: timeText,
            detail: template?.detail ?? "Быстрый ввод",
            category: template?.category ?? .personal,
            icon: template?.icon ?? "checkmark.circle.fill",
            accent: template?.accent ?? .lime
        )
    }

    private static func extractTime(from text: String) -> (titleText: String, timeText: String?) {
        let pattern = #"([01]?\d|2[0-3])[:.]([0-5]\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let fullRange = Range(match.range(at: 0), in: text),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text) else {
            return (text, nil)
        }

        let hours = Int(text[hourRange]) ?? 0
        let minutes = String(text[minuteRange])
        var titleText = text
        titleText.removeSubrange(fullRange)
        titleText = titleText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

        return (titleText, "\(hours):\(minutes)")
    }

    private static func titleCased(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return trimmed
        }

        return first.uppercased() + trimmed.dropFirst()
    }
}

public enum DayflowDeepLink {
    public static let scheme = "dayflow"
    public static let quickAddHost = "quick-add"
    public static let quickAddURL = URL(string: "\(scheme)://\(quickAddHost)")!

    public static func isQuickAdd(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == quickAddHost
    }
}

public enum DayActivityRecurrencePattern: Codable, Equatable {
    case daily
    case weekdays([Int])
    case selectedDates([String])
    case shiftKinds([ShiftKind])
    case afterNight
}

public struct DayActivityRecurrenceRule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var timeMinutes: Int
    public var detail: String
    public var category: DayActivityCategory
    public var icon: String
    public var accent: ActivityAccent
    public var pattern: DayActivityRecurrencePattern
    public var startDayID: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        timeMinutes: Int,
        detail: String,
        category: DayActivityCategory,
        icon: String,
        accent: ActivityAccent,
        pattern: DayActivityRecurrencePattern,
        startDayID: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.timeMinutes = timeMinutes
        self.detail = detail
        self.category = category
        self.icon = icon
        self.accent = accent
        self.pattern = pattern
        self.startDayID = startDayID
        self.isEnabled = isEnabled
    }

    public init(
        activity: NewDayActivity,
        pattern: DayActivityRecurrencePattern,
        starting date: Date,
        calendar: Calendar = .current
    ) throws {
        let parsed = try DayActivity(activity)
        self.init(
            title: parsed.title,
            timeMinutes: parsed.timeMinutes,
            detail: parsed.detail,
            category: parsed.category,
            icon: parsed.icon,
            accent: parsed.accent,
            pattern: pattern,
            startDayID: DayActivity.dayID(for: date, calendar: calendar)
        )
    }

    public func matches(
        date: Date,
        shift: ShiftKind,
        previousShift: ShiftKind,
        calendar: Calendar = .current
    ) -> Bool {
        guard isEnabled else {
            return false
        }

        let currentDayID = DayActivity.dayID(for: date, calendar: calendar)
        switch pattern {
        case .selectedDates(let dayIDs):
            return dayIDs.contains(currentDayID)
        case .daily:
            return currentDayID >= startDayID
        case .weekdays(let weekdays):
            return currentDayID >= startDayID && weekdays.contains(Self.isoWeekday(for: date, calendar: calendar))
        case .shiftKinds(let shifts):
            return currentDayID >= startDayID && shifts.contains(shift)
        case .afterNight:
            return currentDayID >= startDayID && previousShift == .night
        }
    }

    public func activity(on date: Date, calendar: Calendar = .current) -> DayActivity {
        DayActivity(
            title: title,
            timeMinutes: timeMinutes,
            detail: detail,
            category: category,
            icon: icon,
            accent: accent,
            dayID: DayActivity.dayID(for: date, calendar: calendar),
            recurrenceRuleID: id
        )
    }

    public static func isoWeekday(for date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}

public struct DayActivityRecurrenceSkip: Codable, Equatable, Identifiable {
    public var ruleID: UUID
    public var dayID: String

    public var id: String {
        "\(ruleID.uuidString)|\(dayID)"
    }

    public init(ruleID: UUID, dayID: String) {
        self.ruleID = ruleID
        self.dayID = dayID
    }
}

public enum DayHabitGoalUnit: String, Codable, CaseIterable, Equatable, Identifiable {
    case count
    case minutes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .count:
            return "разы"
        case .minutes:
            return "минуты"
        }
    }

    public var shortTitle: String {
        switch self {
        case .count:
            return "раз"
        case .minutes:
            return "мин"
        }
    }
}

public struct DayHabitGoal: Codable, Equatable {
    public var value: Int
    public var unit: DayHabitGoalUnit

    public init(value: Int, unit: DayHabitGoalUnit) {
        self.value = max(1, value)
        self.unit = unit
    }
}

public enum DayHabitLogStatus: String, Codable, Equatable {
    case progress
    case completed
    case skipped
}

public struct DayHabit: Codable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var timeMinutes: Int
    public var detail: String
    public var category: DayActivityCategory
    public var icon: String
    public var accent: ActivityAccent
    public var goal: DayHabitGoal
    public var pattern: DayActivityRecurrencePattern
    public var startDayID: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        timeMinutes: Int,
        detail: String,
        category: DayActivityCategory,
        icon: String,
        accent: ActivityAccent,
        goal: DayHabitGoal,
        pattern: DayActivityRecurrencePattern,
        startDayID: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.timeMinutes = timeMinutes
        self.detail = detail
        self.category = category
        self.icon = icon
        self.accent = accent
        self.goal = goal
        self.pattern = pattern
        self.startDayID = startDayID
        self.isEnabled = isEnabled
    }

    public init(
        activity: NewDayActivity,
        goal: DayHabitGoal,
        pattern: DayActivityRecurrencePattern,
        starting date: Date,
        calendar: Calendar = .current
    ) throws {
        guard goal.value > 0 else {
            throw DayActivityValidationError.invalidHabitGoal
        }

        let parsed = try DayActivity(activity)
        self.init(
            title: parsed.title,
            timeMinutes: parsed.timeMinutes,
            detail: parsed.detail,
            category: parsed.category,
            icon: parsed.icon,
            accent: parsed.accent,
            goal: goal,
            pattern: pattern,
            startDayID: DayActivity.dayID(for: date, calendar: calendar)
        )
    }

    public func matches(
        date: Date,
        shift: ShiftKind,
        previousShift: ShiftKind,
        calendar: Calendar = .current
    ) -> Bool {
        guard isEnabled else {
            return false
        }

        let currentDayID = DayActivity.dayID(for: date, calendar: calendar)
        switch pattern {
        case .selectedDates(let dayIDs):
            return dayIDs.contains(currentDayID)
        case .daily:
            return currentDayID >= startDayID
        case .weekdays(let weekdays):
            return currentDayID >= startDayID && weekdays.contains(DayActivityRecurrenceRule.isoWeekday(for: date, calendar: calendar))
        case .shiftKinds(let shifts):
            return currentDayID >= startDayID && shifts.contains(shift)
        case .afterNight:
            return currentDayID >= startDayID && previousShift == .night
        }
    }

    public func activity(on date: Date, calendar: Calendar = .current) -> DayActivity {
        DayActivity(
            title: title,
            timeMinutes: timeMinutes,
            detail: detail,
            category: category,
            icon: icon,
            accent: accent,
            dayID: DayActivity.dayID(for: date, calendar: calendar),
            habitID: id,
            habitGoalValue: goal.value,
            habitGoalUnit: goal.unit
        )
    }
}

public struct DayHabitLog: Codable, Equatable, Identifiable {
    public var habitID: UUID
    public var dayID: String
    public var value: Int
    public var note: String
    public var status: DayHabitLogStatus

    public var id: String {
        "\(habitID.uuidString)|\(dayID)"
    }

    public init(habitID: UUID, dayID: String, value: Int, note: String = "", status: DayHabitLogStatus) {
        self.habitID = habitID
        self.dayID = dayID
        self.value = max(0, value)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
    }
}

public struct DayHabitProgress: Equatable {
    public var habit: DayHabit
    public var log: DayHabitLog?
    public var currentValue: Int
    public var goalValue: Int
    public var unit: DayHabitGoalUnit
    public var completionPercent: Int
    public var isCompleted: Bool
    public var isSkipped: Bool
    public var currentStreak: Int

    public init(habit: DayHabit, log: DayHabitLog?, currentStreak: Int) {
        self.habit = habit
        self.log = log
        self.currentValue = log?.value ?? 0
        self.goalValue = habit.goal.value
        self.unit = habit.goal.unit
        self.completionPercent = habit.goal.value == 0
            ? 0
            : min(100, Int((Double(currentValue) / Double(habit.goal.value) * 100).rounded()))
        self.isCompleted = log?.status == .completed
        self.isSkipped = log?.status == .skipped
        self.currentStreak = currentStreak
    }
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
    public var recurrenceRuleID: UUID?
    public var habitID: UUID?
    public var habitGoalValue: Int?
    public var habitGoalUnit: DayHabitGoalUnit?

    public var timeText: String {
        Self.timeText(from: timeMinutes)
    }

    public var isHabit: Bool {
        habitID != nil
    }

    public var habitGoalText: String? {
        guard let habitGoalValue, let habitGoalUnit else {
            return nil
        }

        return "\(habitGoalValue) \(habitGoalUnit.shortTitle)"
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
        dayID: String? = nil,
        recurrenceRuleID: UUID? = nil,
        habitID: UUID? = nil,
        habitGoalValue: Int? = nil,
        habitGoalUnit: DayHabitGoalUnit? = nil
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
        self.recurrenceRuleID = recurrenceRuleID
        self.habitID = habitID
        self.habitGoalValue = habitGoalValue
        self.habitGoalUnit = habitGoalUnit
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

public struct ShiftConflict: Equatable, Identifiable {
    public var id: UUID
    public var activityID: UUID
    public var activityTitle: String
    public var activityTimeText: String

    public init(id: UUID = UUID(), activityID: UUID, activityTitle: String, activityTimeText: String) {
        self.id = id
        self.activityID = activityID
        self.activityTitle = activityTitle
        self.activityTimeText = activityTimeText
    }
}

public struct ShiftWorkdaySummary: Equatable, Identifiable {
    public var id: String { dayID }
    public var dayID: String
    public var date: Date
    public var shift: ShiftKind
    public var startMinutes: Int
    public var endMinutes: Int
    public var totalMinutes: Int
    public var regularMinutes: Int
    public var overtimeMinutes: Int
    public var hourlyRate: Double
    public var payMultiplier: Double
    public var overtimeMultiplier: Double
    public var estimatedPay: Double
    public var conflicts: [ShiftConflict]

    public var startTimeText: String {
        DayActivity.timeText(from: startMinutes)
    }

    public var endTimeText: String {
        DayActivity.timeText(from: endMinutes)
    }

    public var totalHoursText: String {
        Self.hoursText(totalMinutes)
    }

    public var payText: String {
        "\(Int(estimatedPay.rounded())) ₽"
    }

    public init(dayID: String, date: Date, shift: ShiftKind, settings: ShiftPaySettings, conflicts: [ShiftConflict] = []) {
        self.dayID = dayID
        self.date = date
        self.shift = shift
        self.startMinutes = settings.startMinutes
        self.endMinutes = settings.endMinutes
        self.totalMinutes = settings.durationMinutes
        self.regularMinutes = min(settings.durationMinutes, settings.overtimeThresholdMinutes)
        self.overtimeMinutes = max(0, settings.durationMinutes - settings.overtimeThresholdMinutes)
        self.hourlyRate = settings.hourlyRate
        self.payMultiplier = settings.payMultiplier
        self.overtimeMultiplier = settings.overtimeMultiplier
        let regularPay = (Double(regularMinutes) / 60) * settings.hourlyRate * settings.payMultiplier
        let overtimePay = (Double(overtimeMinutes) / 60) * settings.hourlyRate * settings.payMultiplier * settings.overtimeMultiplier
        self.estimatedPay = regularPay + overtimePay
        self.conflicts = conflicts
    }

    public static func hoursText(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60
        if minutes % 60 == 0 {
            return "\(minutes / 60) ч"
        }

        return String(format: "%.1f ч", hours)
    }
}

public struct ShiftMonthPayrollSummary: Equatable {
    public var startDate: Date
    public var endDate: Date
    public var days: [ShiftWorkdaySummary]

    public var workedDays: Int {
        days.filter { $0.totalMinutes > 0 }.count
    }

    public var totalMinutes: Int {
        days.reduce(0) { $0 + $1.totalMinutes }
    }

    public var overtimeMinutes: Int {
        days.reduce(0) { $0 + $1.overtimeMinutes }
    }

    public var estimatedPay: Double {
        days.reduce(0) { $0 + $1.estimatedPay }
    }

    public var conflicts: [ShiftConflict] {
        days.flatMap(\.conflicts)
    }

    public init(startDate: Date, endDate: Date, days: [ShiftWorkdaySummary]) {
        self.startDate = startDate
        self.endDate = endDate
        self.days = days
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
