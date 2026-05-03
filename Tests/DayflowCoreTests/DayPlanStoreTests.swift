import XCTest
@testable import DayflowCore

final class DayPlanStoreTests: XCTestCase {
    func testQuickCaptureParsesKnownGymActivityWithExplicitTime() throws {
        let activity = try DayflowQuickCaptureParser.parse("зал 20:00", fallbackTimeText: "12:00")

        XCTAssertEqual(activity.title, "Зал")
        XCTAssertEqual(activity.timeText, "20:00")
        XCTAssertEqual(activity.detail, "Силовая тренировка")
        XCTAssertEqual(activity.category, .body)
        XCTAssertEqual(activity.icon, "dumbbell.fill")
        XCTAssertEqual(activity.accent, .lime)
    }

    func testQuickCaptureUsesTemplateDefaultTimeWhenTimeIsMissing() throws {
        let activity = try DayflowQuickCaptureParser.parse("бег", fallbackTimeText: "12:00")

        XCTAssertEqual(activity.title, "Бег")
        XCTAssertEqual(activity.timeText, "7:00")
        XCTAssertEqual(activity.detail, "Парк или дорожка")
        XCTAssertEqual(activity.category, .body)
        XCTAssertEqual(activity.icon, "figure.run")
    }

    func testQuickCaptureParsesUnknownActivityAsPersonalTask() throws {
        let activity = try DayflowQuickCaptureParser.parse("созвон 14.30", fallbackTimeText: "12:00")

        XCTAssertEqual(activity.title, "Созвон")
        XCTAssertEqual(activity.timeText, "14:30")
        XCTAssertEqual(activity.detail, "Быстрый ввод")
        XCTAssertEqual(activity.category, .personal)
        XCTAssertEqual(activity.icon, "checkmark.circle.fill")
    }

    func testRepeatActivitiesCopiesPreviousDayAndResetsCompletion() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let yesterday = addingDays(-1, to: today)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { today })
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: yesterday)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: yesterday)
        let yesterdayActivityID = try XCTUnwrap(store.activities(on: yesterday).first?.id)
        try store.setCompleted(yesterdayActivityID, true)

        let copiedCount = try store.repeatActivities(from: yesterday, to: today)

        let todayActivities = store.activities(on: today)
        XCTAssertEqual(copiedCount, 2)
        XCTAssertEqual(todayActivities.map(\.title), ["Бег", "Зал"])
        XCTAssertEqual(todayActivities.map(\.isCompleted), [false, false])
        XCTAssertEqual(Set(todayActivities.map(\.dayID)), [DayActivity.dayID(for: today, calendar: testCalendar)])
    }

    func testRepeatActivitiesSkipsExactDuplicatesOnTargetDay() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let yesterday = addingDays(-1, to: today)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { today })
        let run = NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky)
        try store.add(run, on: yesterday)
        try store.add(run, on: today)

        let copiedCount = try store.repeatActivities(from: yesterday, to: today)

        XCTAssertEqual(copiedCount, 0)
        XCTAssertEqual(store.activities(on: today).map(\.title), ["Бег"])
    }

    func testDailyRecurringActivityMaterializesForFutureDayOnce() throws {
        let start = date(year: 2026, month: 5, day: 3)
        let tomorrow = addingDays(1, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { start })
        try store.addRecurringActivity(
            NewDayActivity(title: "Вода", timeText: "10:00", detail: "Стакан", category: .body, icon: "drop.fill", accent: .sky),
            pattern: .daily,
            starting: start
        )

        XCTAssertEqual(store.activities(on: tomorrow).map(\.title), ["Вода"])
        XCTAssertEqual(store.activities(on: tomorrow).map(\.title), ["Вода"])
        XCTAssertEqual(store.activities(on: tomorrow).first?.recurrenceRuleID, store.recurrenceRules.first?.id)
    }

    func testWeekdayRecurringActivityOnlyMatchesSelectedWeekdays() throws {
        let sunday = date(year: 2026, month: 5, day: 3)
        let monday = addingDays(1, to: sunday)
        let tuesday = addingDays(2, to: sunday)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { sunday })
        try store.addRecurringActivity(
            NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime),
            pattern: .weekdays([1, 3]),
            starting: sunday
        )

        XCTAssertEqual(store.activities(on: monday).map(\.title), ["Зал"])
        XCTAssertEqual(store.activities(on: tuesday), [])
    }

    func testSelectedDatesRecurringActivityOnlyMatchesChosenDates() throws {
        let start = date(year: 2026, month: 5, day: 3)
        let selected = addingDays(2, to: start)
        let skipped = addingDays(3, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { start })
        try store.addRecurringActivity(
            NewDayActivity(title: "Массаж", timeText: "18:00", detail: "Запись", category: .personal, icon: "sparkles", accent: .rose),
            pattern: .selectedDates([DayActivity.dayID(for: selected, calendar: testCalendar)]),
            starting: start
        )

        XCTAssertEqual(store.activities(on: selected).map(\.title), ["Массаж"])
        XCTAssertEqual(store.activities(on: skipped), [])
    }

    func testShiftRecurringActivityMatchesEffectiveShift() throws {
        let start = date(year: 2026, month: 5, day: 3)
        let restDay = addingDays(2, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { start })
        try store.setShiftSchedule(.makePreset(.twoTwo, starting: start, calendar: testCalendar))
        try store.addRecurringActivity(
            NewDayActivity(title: "Восстановление", timeText: "12:00", detail: "Легкий день", category: .personal, icon: "leaf.fill", accent: .lime),
            pattern: .shiftKinds([.rest]),
            starting: start
        )

        XCTAssertEqual(store.activities(on: start), [])
        XCTAssertEqual(store.activities(on: restDay).map(\.title), ["Восстановление"])
    }

    func testAfterNightRecurringActivityMatchesDayAfterNightShift() throws {
        let start = date(year: 2026, month: 5, day: 3)
        let nightDay = addingDays(1, to: start)
        let recoveryDay = addingDays(2, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { start })
        try store.setShiftSchedule(.makePreset(.dayNightRest, starting: start, calendar: testCalendar))
        try store.addRecurringActivity(
            NewDayActivity(title: "Отсып", timeText: "11:00", detail: "Без будильника", category: .personal, icon: "moon.zzz.fill", accent: .rose),
            pattern: .afterNight,
            starting: start
        )

        XCTAssertEqual(store.activities(on: nightDay), [])
        XCTAssertEqual(store.activities(on: recoveryDay).map(\.title), ["Отсып"])
    }

    func testDeletingMaterializedRecurringActivitySkipsOnlyThatDay() throws {
        let start = date(year: 2026, month: 5, day: 3)
        let tomorrow = addingDays(1, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), calendar: testCalendar, todayProvider: { start })
        try store.addRecurringActivity(
            NewDayActivity(title: "Вода", timeText: "10:00", detail: "Стакан", category: .body, icon: "drop.fill", accent: .sky),
            pattern: .daily,
            starting: start
        )
        let activity = try XCTUnwrap(store.activities(on: start).first)

        try store.remove(activity.id)

        XCTAssertEqual(store.activities(on: start), [])
        XCTAssertEqual(store.activities(on: tomorrow).map(\.title), ["Вода"])
    }

    func testUserDefaultsStorageMigratesLegacyDataToSharedStorage() throws {
        let legacyDefaults = makeIsolatedDefaults()
        let sharedDefaults = makeIsolatedDefaults()
        defer {
            remove(defaults: legacyDefaults)
            remove(defaults: sharedDefaults)
        }

        let legacyStorage = UserDefaultsActivityStorage(defaults: legacyDefaults)
        let sharedStorage = UserDefaultsActivityStorage(defaults: sharedDefaults)
        let day = date(year: 2026, month: 5, day: 3)
        let activity = DayActivity(title: "Бег", timeMinutes: 420, detail: "Парк", category: .body, icon: "figure.run", accent: .sky, dayID: DayActivity.dayID(for: day, calendar: testCalendar))
        let details = DayDetails(dayID: DayActivity.dayID(for: day, calendar: testCalendar), note: "Взять форму", shift: .night, hasManualShift: true)
        let schedule = ShiftSchedule.makePreset(.twoDayTwoNight, starting: day, calendar: testCalendar)

        try legacyStorage.saveActivities([activity])
        try legacyStorage.saveDayDetails([details])
        try legacyStorage.saveShiftSchedule(schedule)

        let migrated = try DayflowStorageMigration.migrateIfNeeded(from: legacyStorage, to: sharedStorage)

        XCTAssertTrue(migrated)
        XCTAssertEqual(try sharedStorage.loadActivities(), [activity])
        XCTAssertEqual(try sharedStorage.loadDayDetails(), [details])
        XCTAssertEqual(try sharedStorage.loadShiftSchedule(), schedule)
    }

    func testMigrationDoesNotOverwriteExistingSharedStorage() throws {
        let legacyDefaults = makeIsolatedDefaults()
        let sharedDefaults = makeIsolatedDefaults()
        defer {
            remove(defaults: legacyDefaults)
            remove(defaults: sharedDefaults)
        }

        let legacyStorage = UserDefaultsActivityStorage(defaults: legacyDefaults)
        let sharedStorage = UserDefaultsActivityStorage(defaults: sharedDefaults)
        let legacyActivity = DayActivity(title: "Старое", timeMinutes: 420, detail: "Legacy", category: .body, icon: "figure.run", accent: .sky)
        let sharedActivity = DayActivity(title: "Новое", timeMinutes: 480, detail: "Shared", category: .personal, icon: "moon.fill", accent: .rose)

        try legacyStorage.saveActivities([legacyActivity])
        try sharedStorage.saveActivities([sharedActivity])

        let migrated = try DayflowStorageMigration.migrateIfNeeded(from: legacyStorage, to: sharedStorage)

        XCTAssertFalse(migrated)
        XCTAssertEqual(try sharedStorage.loadActivities(), [sharedActivity])
    }

    func testWidgetSnapshotUsesRealTodayData() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: today)
        try store.setCompleted(try XCTUnwrap(store.activities(on: today).first?.id), true)
        try store.setShiftSchedule(.makePreset(.twoTwo, starting: today, calendar: testCalendar))

        let snapshot = DayflowWidgetSnapshotBuilder.snapshot(on: today, storage: storage, calendar: testCalendar)

        XCTAssertEqual(snapshot.totalCount, 2)
        XCTAssertEqual(snapshot.completedCount, 1)
        XCTAssertEqual(snapshot.progressPercent, 50)
        XCTAssertEqual(snapshot.nextActivities.map(\.title), ["Зал"])
        XCTAssertEqual(snapshot.effectiveShift, .day)
        XCTAssertEqual(snapshot.scheduleName, "2/2")
    }

    func testWidgetSnapshotBuildsWeeklyPulse() throws {
        let today = date(year: 2026, month: 5, day: 8)
        let yesterday = addingDays(-1, to: today)
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: yesterday)
        try store.setCompleted(try XCTUnwrap(store.activities(on: yesterday).first?.id), true)

        let snapshot = DayflowWidgetSnapshotBuilder.snapshot(on: today, storage: storage, calendar: testCalendar)

        XCTAssertEqual(snapshot.weekDays.count, 7)
        XCTAssertEqual(snapshot.weekDays.last?.dayID, DayActivity.dayID(for: today, calendar: testCalendar))
        XCTAssertEqual(snapshot.weekDays.last?.totalCount, 1)
        XCTAssertEqual(snapshot.weekDays[snapshot.weekDays.count - 2].completionPercent, 100)
    }

    func testWidgetActionCompletesActivity() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)

        let activityID = try XCTUnwrap(store.activities(on: today).first?.id)
        let changed = try DayflowWidgetActionService.completeActivity(id: activityID, storage: storage, calendar: testCalendar, todayProvider: { today })

        let reloadedStore = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })
        XCTAssertTrue(changed)
        XCTAssertEqual(reloadedStore.activities(on: today).first?.isCompleted, true)
    }

    func testWidgetActionIsIdempotentForCompletedActivity() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)

        let activityID = try XCTUnwrap(store.activities(on: today).first?.id)
        _ = try DayflowWidgetActionService.completeActivity(id: activityID, storage: storage, calendar: testCalendar, todayProvider: { today })
        let changedAgain = try DayflowWidgetActionService.completeActivity(id: activityID, storage: storage, calendar: testCalendar, todayProvider: { today })

        let reloadedStore = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })
        XCTAssertFalse(changedAgain)
        XCTAssertEqual(reloadedStore.activities(on: today).first?.isCompleted, true)
    }

    func testPrivacyDocumentDeclaresLocalOnlyDataAndNoTracking() throws {
        let document = AppLegalDocument.privacyPolicy
        let body = document.body

        XCTAssertTrue(body.contains("UserDefaults"))
        XCTAssertTrue(body.contains("не отправляет"))
        XCTAssertTrue(body.contains("не использует трекинг"))
        XCTAssertTrue(body.contains("можно удалить"))
        XCTAssertTrue(body.contains("локальные напоминания"))
    }

    func testLegalDocumentsExposePublicReleaseUrls() throws {
        XCTAssertEqual(AppLegalDocument.privacyPolicy.publicURLString, "https://exitze.github.io/DayFlow/privacy.html")
        XCTAssertEqual(AppLegalDocument.terms.publicURLString, "https://exitze.github.io/DayFlow/terms.html")
        XCTAssertEqual(AppLegalDocument.support.publicURLString, "https://exitze.github.io/DayFlow/support.html")
    }

    func testSupportDocumentIsUserFacingInsteadOfAppStoreInstructions() throws {
        let body = AppLegalDocument.support.body

        XCTAssertTrue(body.contains("Exitze@icloud.com"))
        XCTAssertTrue(body.contains("Dayflow"))
        XCTAssertFalse(body.contains("App Store Connect"))
    }

    func testNotificationPlanReturnsNoRequestsWhenNotificationsAreDisabled() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let activity = DayActivity(
            title: "Бег",
            timeMinutes: 420,
            detail: "Парк",
            category: .body,
            icon: "figure.run",
            accent: .sky,
            dayID: DayActivity.dayID(for: today, calendar: testCalendar)
        )

        let plan = DayflowNotificationPlanBuilder.makePlan(
            settings: .defaults,
            activities: [activity],
            dayDetails: [],
            shiftSchedule: nil,
            now: hour(6, minute: 0, on: today),
            calendar: testCalendar
        )

        XCTAssertEqual(plan, [])
    }

    func testMorningNotificationSummarizesRealTodayPlanAndShift() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let settings = DayflowNotificationSettings(
            isEnabled: true,
            morningPlanEnabled: true,
            activityRemindersEnabled: false,
            shiftReminderEnabled: false,
            eveningReviewEnabled: false
        )
        let activities = [
            DayActivity(title: "Бег", timeMinutes: 420, detail: "Парк", category: .body, icon: "figure.run", accent: .sky, dayID: DayActivity.dayID(for: today, calendar: testCalendar)),
            DayActivity(title: "Зал", timeMinutes: 1200, detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime, dayID: DayActivity.dayID(for: today, calendar: testCalendar))
        ]
        let schedule = ShiftSchedule.makePreset(.twoTwo, starting: today, calendar: testCalendar)

        let plan = DayflowNotificationPlanBuilder.makePlan(
            settings: settings,
            activities: activities,
            dayDetails: [],
            shiftSchedule: schedule,
            now: hour(6, minute: 0, on: today),
            calendar: testCalendar
        )

        let request = try XCTUnwrap(plan.first { $0.kind == .morningPlan })
        XCTAssertEqual(request.date, hour(8, minute: 30, on: today))
        XCTAssertTrue(request.title.contains("План дня"))
        XCTAssertTrue(request.body.contains("2 дела"))
        XCTAssertTrue(request.body.contains("Бег"))
        XCTAssertTrue(request.body.contains("Смена: День"))
    }

    func testActivityReminderSchedulesBeforeRealActivityTime() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let settings = DayflowNotificationSettings(
            isEnabled: true,
            morningPlanEnabled: false,
            activityRemindersEnabled: true,
            shiftReminderEnabled: false,
            eveningReviewEnabled: false,
            activityLeadMinutes: 15
        )
        let activity = DayActivity(
            title: "Бег",
            timeMinutes: 420,
            detail: "Парк",
            category: .body,
            icon: "figure.run",
            accent: .sky,
            dayID: DayActivity.dayID(for: today, calendar: testCalendar)
        )

        let plan = DayflowNotificationPlanBuilder.makePlan(
            settings: settings,
            activities: [activity],
            dayDetails: [],
            shiftSchedule: nil,
            now: hour(6, minute: 0, on: today),
            calendar: testCalendar
        )

        let request = try XCTUnwrap(plan.first { $0.kind == .activityReminder })
        XCTAssertEqual(request.date, hour(6, minute: 45, on: today))
        XCTAssertTrue(request.title.contains("Бег"))
        XCTAssertTrue(request.title.contains("15 мин"))
        XCTAssertTrue(request.body.contains("Парк"))
    }

    func testShiftReminderUsesAutomaticTomorrowShift() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let settings = DayflowNotificationSettings(
            isEnabled: true,
            morningPlanEnabled: false,
            activityRemindersEnabled: false,
            shiftReminderEnabled: true,
            eveningReviewEnabled: false
        )
        let schedule = ShiftSchedule.makePreset(.twoDayTwoNight, starting: today, calendar: testCalendar)

        let plan = DayflowNotificationPlanBuilder.makePlan(
            settings: settings,
            activities: [],
            dayDetails: [],
            shiftSchedule: schedule,
            now: hour(10, minute: 0, on: today),
            calendar: testCalendar
        )

        let request = try XCTUnwrap(plan.first { $0.kind == .shiftReminder })
        XCTAssertEqual(request.date, hour(19, minute: 0, on: today))
        XCTAssertTrue(request.title.contains("Завтра"))
        XCTAssertTrue(request.body.contains("День"))
        XCTAssertTrue(request.body.contains("2Д/2Н"))
    }

    func testEveningReviewCountsOpenActivities() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let settings = DayflowNotificationSettings(
            isEnabled: true,
            morningPlanEnabled: false,
            activityRemindersEnabled: false,
            shiftReminderEnabled: false,
            eveningReviewEnabled: true
        )
        let activities = [
            DayActivity(title: "Бег", timeMinutes: 420, detail: "Парк", category: .body, icon: "figure.run", accent: .sky, isCompleted: true, dayID: DayActivity.dayID(for: today, calendar: testCalendar)),
            DayActivity(title: "Зал", timeMinutes: 1200, detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime, dayID: DayActivity.dayID(for: today, calendar: testCalendar))
        ]

        let plan = DayflowNotificationPlanBuilder.makePlan(
            settings: settings,
            activities: activities,
            dayDetails: [],
            shiftSchedule: nil,
            now: hour(19, minute: 0, on: today),
            calendar: testCalendar
        )

        let request = try XCTUnwrap(plan.first { $0.kind == .eveningReview })
        XCTAssertEqual(request.date, hour(21, minute: 30, on: today))
        XCTAssertTrue(request.body.contains("1 открыто"))
        XCTAssertTrue(request.body.contains("Зал"))
    }

    func testStoreStartsEmptyWhenStorageHasNoActivities() throws {
        let store = DayPlanStore(storage: MemoryActivityStorage())

        XCTAssertEqual(store.activities, [])
        XCTAssertEqual(store.summary.totalCount, 0)
        XCTAssertEqual(store.summary.progressPercent, 0)
    }

    func testAddingActivitiesSortsByTimeAndPersists() throws {
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage)

        try store.add(
            NewDayActivity(
                title: "Зал",
                timeText: "20:00",
                detail: "Силовая, 60 мин",
                category: .body,
                icon: "dumbbell.fill",
                accent: .lime
            )
        )
        try store.add(
            NewDayActivity(
                title: "Бег",
                timeText: "7:00",
                detail: "Парк",
                category: .body,
                icon: "figure.run",
                accent: .sky
            )
        )

        XCTAssertEqual(store.activities.map(\.title), ["Бег", "Зал"])
        XCTAssertEqual(storage.savedActivities.map(\.title), ["Бег", "Зал"])
    }

    func testOnboardingShiftScenarioRecommendsWorkRecoveryAndBodyTemplates() throws {
        let templates = DayflowOnboardingCatalog.recommendedTemplates(for: .shifts)

        XCTAssertEqual(DayflowOnboardingScenario.shifts.title, "Сменный график")
        XCTAssertEqual(templates.prefix(4).map(\.id), ["work", "sleep", "water", "gym"])
        XCTAssertTrue(templates.allSatisfy { !$0.title.isEmpty && !$0.timeText.isEmpty })
    }

    func testOnboardingPlanBuildsSelectedActivitiesAndShiftSchedule() throws {
        let start = date(year: 2026, month: 5, day: 3)
        let plan = DayflowOnboardingPlan(
            scenario: .shifts,
            shiftPreset: .dayNightRest,
            selectedTemplateIDs: ["run", "gym", "run", "missing"]
        )

        let activities = DayflowOnboardingBuilder.makeActivities(from: plan)
        let schedule = DayflowOnboardingBuilder.makeShiftSchedule(from: plan, starting: start, calendar: testCalendar)

        XCTAssertEqual(activities.map(\.title), ["Бег", "Зал"])
        XCTAssertEqual(activities.map(\.timeText), ["7:00", "20:00"])
        XCTAssertEqual(schedule?.preset, .dayNightRest)
        XCTAssertEqual(schedule?.shift(on: start, calendar: testCalendar), .day)
    }

    func testApplyingOnboardingCreatesTodayActivitiesAndSchedule() throws {
        let today = date(year: 2026, month: 5, day: 3)
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage, calendar: testCalendar, todayProvider: { today })
        let plan = DayflowOnboardingPlan(
            scenario: .body,
            shiftPreset: .twoTwo,
            selectedTemplateIDs: ["run", "meditation"]
        )

        try store.applyOnboarding(plan, on: today)

        XCTAssertEqual(store.activities(on: today).map(\.title), ["Бег", "Медитация"])
        XCTAssertEqual(
            store.activities(on: today).map(\.dayID),
            [
                DayActivity.dayID(for: today, calendar: testCalendar),
                DayActivity.dayID(for: today, calendar: testCalendar)
            ]
        )
        XCTAssertEqual(store.shiftSchedule?.preset, .twoTwo)
        XCTAssertEqual(store.effectiveShift(for: today), .day)
    }

    func testFilteringUsesRealActivityCategory() throws {
        let store = DayPlanStore(storage: MemoryActivityStorage())
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky))
        try store.add(NewDayActivity(title: "Медитация", timeText: "22:30", detail: "15 мин", category: .personal, icon: "moon.fill", accent: .rose))

        XCTAssertEqual(store.activities(filteredBy: .all).map(\.title), ["Бег", "Медитация"])
        XCTAssertEqual(store.activities(filteredBy: .body).map(\.title), ["Бег"])
        XCTAssertEqual(store.activities(filteredBy: .personal).map(\.title), ["Медитация"])
    }

    func testSummaryProgressComesFromCompletedActivities() throws {
        let store = DayPlanStore(storage: MemoryActivityStorage())
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky))
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime))
        try store.add(NewDayActivity(title: "Медитация", timeText: "22:30", detail: "15 мин", category: .personal, icon: "moon.fill", accent: .rose))

        try store.setCompleted(store.activities[0].id, true)
        try store.setCompleted(store.activities[1].id, true)

        XCTAssertEqual(store.summary.totalCount, 3)
        XCTAssertEqual(store.summary.completedCount, 2)
        XCTAssertEqual(store.summary.progressPercent, 67)
    }

    func testValidationRejectsBlankTitleAndInvalidTime() throws {
        let store = DayPlanStore(storage: MemoryActivityStorage())

        XCTAssertThrowsError(
            try store.add(NewDayActivity(title: "   ", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky))
        )

        XCTAssertThrowsError(
            try store.add(NewDayActivity(title: "Бег", timeText: "25:70", detail: "Парк", category: .body, icon: "figure.run", accent: .sky))
        )

        XCTAssertEqual(store.activities, [])
    }

    func testCalendarActivitiesAreScopedToSelectedDay() throws {
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage)
        let today = date(year: 2026, month: 5, day: 2)
        let tomorrow = date(year: 2026, month: 5, day: 3)

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: tomorrow)

        XCTAssertEqual(store.activities(on: today).map(\.title), ["Бег"])
        XCTAssertEqual(store.activities(on: tomorrow).map(\.title), ["Зал"])
        XCTAssertEqual(store.summary(on: today).totalCount, 1)
    }

    func testDayDetailsPersistNotesAndShift() throws {
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage)
        let day = date(year: 2026, month: 5, day: 2)

        try store.setNote("Не забыть форму", for: day)
        try store.setShift(.night, for: day)

        XCTAssertEqual(store.details(for: day).note, "Не забыть форму")
        XCTAssertEqual(store.details(for: day).shift, .night)
        XCTAssertEqual(storage.savedDayDetails.first?.note, "Не забыть форму")
        XCTAssertEqual(storage.savedDayDetails.first?.shift, .night)
    }

    func testDefaultAddUsesConfiguredTodayAcrossHomeAndCalendar() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let tomorrow = date(year: 2026, month: 5, day: 3)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky))

        XCTAssertEqual(store.activities(on: today).map(\.title), ["Бег"])
        XCTAssertEqual(store.activities(filteredBy: .body).map(\.title), ["Бег"])
        XCTAssertEqual(store.summary.totalCount, 1)
        XCTAssertEqual(store.activities(on: tomorrow), [])
    }

    func testFutureCalendarActivityDoesNotPolluteHomeToday() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let tomorrow = date(year: 2026, month: 5, day: 3)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: tomorrow)

        XCTAssertEqual(store.activities(on: tomorrow).map(\.title), ["Зал"])
        XCTAssertEqual(store.activities(filteredBy: .all), [])
        XCTAssertEqual(store.summary.totalCount, 0)
    }

    func testCompletingFromOneTabUpdatesSameDaySummaryForOtherTab() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)

        let calendarActivity = try XCTUnwrap(store.activities(on: today).first)
        try store.setCompleted(calendarActivity.id, true)

        XCTAssertEqual(store.summary(on: today).completedCount, 1)
        XCTAssertEqual(store.summary.completedCount, 1)
        XCTAssertEqual(store.activities(filteredBy: .body).first?.isCompleted, true)
    }

    func testRemovingFromOneTabRemovesFromSameDayEverywhere() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })
        try store.add(NewDayActivity(title: "Медитация", timeText: "22:00", detail: "15 мин", category: .personal, icon: "moon.fill", accent: .rose), on: today)

        let activity = try XCTUnwrap(store.activities(on: today).first)
        try store.remove(activity.id)

        XCTAssertEqual(store.activities(on: today), [])
        XCTAssertEqual(store.activities(filteredBy: .all), [])
        XCTAssertEqual(store.summary.totalCount, 0)
    }

    func testLegacyActivitiesWithoutDayBelongToConfiguredTodayOnly() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let tomorrow = date(year: 2026, month: 5, day: 3)
        let storage = MemoryActivityStorage()
        storage.activitiesToLoad = [
            DayActivity(title: "Бег", timeMinutes: 420, detail: "Парк", category: .body, icon: "figure.run", accent: .sky)
        ]
        let store = DayPlanStore(storage: storage, todayProvider: { today })

        XCTAssertEqual(store.activities(on: today).map(\.title), ["Бег"])
        XCTAssertEqual(store.activities(on: tomorrow), [])
    }

    func testLegacyActivitiesWithoutDayStayOnLaunchDayAfterDayChanges() throws {
        let launchDay = date(year: 2026, month: 5, day: 2)
        let nextDay = date(year: 2026, month: 5, day: 3)
        var currentDay = launchDay
        let storage = MemoryActivityStorage()
        storage.activitiesToLoad = [
            DayActivity(title: "Бег", timeMinutes: 420, detail: "Парк", category: .body, icon: "figure.run", accent: .sky)
        ]
        let store = DayPlanStore(storage: storage, todayProvider: { currentDay })

        currentDay = nextDay

        XCTAssertEqual(store.activities(filteredBy: .all), [])
        XCTAssertEqual(store.activities(on: launchDay).map(\.title), ["Бег"])
        XCTAssertEqual(store.activities(on: nextDay), [])
        XCTAssertEqual(storage.savedActivities.first?.dayID, DayActivity.dayID(for: launchDay, calendar: testCalendar))
    }

    func testCurrentDayRefreshChangesOnlyAfterCalendarDayBoundary() throws {
        let currentDay = date(year: 2026, month: 5, day: 2)
        let sameDayLater = hour(23, minute: 55, on: currentDay)
        let nextDay = date(year: 2026, month: 5, day: 3)

        XCTAssertEqual(DayflowCurrentDay.refreshed(currentDay, using: sameDayLater, calendar: testCalendar), currentDay)
        XCTAssertEqual(DayflowCurrentDay.refreshed(currentDay, using: nextDay, calendar: testCalendar), nextDay)
    }

    func testCalendarMonthNavigationPreservesDayWhenPossible() throws {
        let may15 = date(year: 2026, month: 5, day: 15)
        let april15 = DayflowCalendarMonthNavigator.date(byAddingMonths: -1, to: may15, calendar: testCalendar)
        let june15 = DayflowCalendarMonthNavigator.date(byAddingMonths: 1, to: may15, calendar: testCalendar)

        XCTAssertEqual(april15, date(year: 2026, month: 4, day: 15))
        XCTAssertEqual(june15, date(year: 2026, month: 6, day: 15))
    }

    func testCalendarMonthNavigationClampsToLastDayOfShortMonth() throws {
        let january31 = date(year: 2026, month: 1, day: 31)
        let februaryDate = DayflowCalendarMonthNavigator.date(byAddingMonths: 1, to: january31, calendar: testCalendar)

        XCTAssertEqual(februaryDate, date(year: 2026, month: 2, day: 28))
    }

    func testStoredCalendarStateReloadsAcrossTabsAndLaunches() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let storage = MemoryActivityStorage()
        let firstStore = DayPlanStore(storage: storage, todayProvider: { today })

        try firstStore.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try firstStore.setCompleted(try XCTUnwrap(firstStore.activities(on: today).first).id, true)
        try firstStore.setShift(.morning, for: today)
        try firstStore.setNote("Взять форму", for: today)

        let reloadedStore = DayPlanStore(storage: storage, todayProvider: { today })

        XCTAssertEqual(reloadedStore.activities(filteredBy: .body).map(\.title), ["Бег"])
        XCTAssertEqual(reloadedStore.summary.completedCount, 1)
        XCTAssertEqual(reloadedStore.details(for: today).shift, .morning)
        XCTAssertEqual(reloadedStore.details(for: today).note, "Взять форму")
    }

    func testTwoTwoScheduleRepeatsFromStartDate() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { start })

        try store.setShiftSchedule(.makePreset(.twoTwo, starting: start))

        XCTAssertEqual(store.effectiveShift(for: start), .day)
        XCTAssertEqual(store.effectiveShift(for: addingDays(1, to: start)), .day)
        XCTAssertEqual(store.effectiveShift(for: addingDays(2, to: start)), .rest)
        XCTAssertEqual(store.effectiveShift(for: addingDays(3, to: start)), .rest)
        XCTAssertEqual(store.effectiveShift(for: addingDays(4, to: start)), .day)
    }

    func testTwoFiveScheduleRepeatsFromStartDate() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { start })

        try store.setShiftSchedule(.makePreset(.twoFive, starting: start))

        XCTAssertEqual(store.effectiveShift(for: start), .day)
        XCTAssertEqual(store.effectiveShift(for: addingDays(1, to: start)), .day)
        XCTAssertEqual(store.effectiveShift(for: addingDays(2, to: start)), .rest)
        XCTAssertEqual(store.effectiveShift(for: addingDays(6, to: start)), .rest)
        XCTAssertEqual(store.effectiveShift(for: addingDays(7, to: start)), .day)
    }

    func testDayNightScheduleIncludesNightAndRecovery() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { start })

        try store.setShiftSchedule(.makePreset(.twoDayTwoNight, starting: start))

        XCTAssertEqual(store.effectiveShift(for: start), .day)
        XCTAssertEqual(store.effectiveShift(for: addingDays(1, to: start)), .day)
        XCTAssertEqual(store.effectiveShift(for: addingDays(2, to: start)), .night)
        XCTAssertEqual(store.effectiveShift(for: addingDays(3, to: start)), .night)
        XCTAssertEqual(store.effectiveShift(for: addingDays(4, to: start)), .recovery)
        XCTAssertEqual(store.effectiveShift(for: addingDays(5, to: start)), .rest)
    }

    func testDayNightRestPresetRepeatsDayNightRecoveryRest() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let schedule = ShiftSchedule.makePreset(.dayNightRest, starting: start, calendar: testCalendar)

        XCTAssertEqual(schedule.name, "День/Ночь")
        XCTAssertEqual(schedule.cycle, [.day, .night, .recovery, .rest])
        XCTAssertEqual(schedule.shift(on: start, calendar: testCalendar), .day)
        XCTAssertEqual(schedule.shift(on: addingDays(1, to: start), calendar: testCalendar), .night)
        XCTAssertEqual(schedule.shift(on: addingDays(2, to: start), calendar: testCalendar), .recovery)
        XCTAssertEqual(schedule.shift(on: addingDays(3, to: start), calendar: testCalendar), .rest)
        XCTAssertEqual(schedule.shift(on: addingDays(4, to: start), calendar: testCalendar), .day)
    }

    func testFiveTwoPresetRepeatsFiveWorkDaysAndTwoRestDays() throws {
        let start = date(year: 2026, month: 5, day: 4)
        let schedule = ShiftSchedule.makePreset(.fiveTwo, starting: start, calendar: testCalendar)

        XCTAssertEqual(schedule.name, "5/2")
        XCTAssertEqual(schedule.cycle, [.day, .day, .day, .day, .day, .rest, .rest])
        XCTAssertEqual(schedule.shift(on: addingDays(4, to: start), calendar: testCalendar), .day)
        XCTAssertEqual(schedule.shift(on: addingDays(5, to: start), calendar: testCalendar), .rest)
        XCTAssertEqual(schedule.shift(on: addingDays(7, to: start), calendar: testCalendar), .day)
    }

    func testCustomShiftFormulaBuildsCycleInDayNightRecoveryRestOrder() throws {
        let formula = ShiftScheduleFormula(dayCount: 3, nightCount: 4, recoveryCount: 1, restCount: 5)

        XCTAssertEqual(formula.cycle, [
            .day, .day, .day,
            .night, .night, .night, .night,
            .recovery,
            .rest, .rest, .rest, .rest, .rest
        ])
        XCTAssertEqual(formula.title, "3Д · 4Н · 1О · 5В")
    }

    func testCustomShiftScheduleUsesFormulaFromSelectedStartDate() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let formula = ShiftScheduleFormula(dayCount: 1, nightCount: 1, recoveryCount: 1, restCount: 2)
        let schedule = try ShiftSchedule.makeCustom(formula: formula, starting: start, calendar: testCalendar)

        XCTAssertEqual(schedule.preset, .custom)
        XCTAssertEqual(schedule.name, "1Д · 1Н · 1О · 2В")
        XCTAssertEqual(schedule.shift(on: start, calendar: testCalendar), .day)
        XCTAssertEqual(schedule.shift(on: addingDays(1, to: start), calendar: testCalendar), .night)
        XCTAssertEqual(schedule.shift(on: addingDays(2, to: start), calendar: testCalendar), .recovery)
        XCTAssertEqual(schedule.shift(on: addingDays(3, to: start), calendar: testCalendar), .rest)
        XCTAssertEqual(schedule.shift(on: addingDays(5, to: start), calendar: testCalendar), .day)
    }

    func testCustomShiftScheduleRejectsEmptyFormula() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let formula = ShiftScheduleFormula(dayCount: 0, nightCount: 0, recoveryCount: 0, restCount: 0)

        XCTAssertThrowsError(
            try ShiftSchedule.makeCustom(formula: formula, starting: start, calendar: testCalendar)
        ) { error in
            XCTAssertEqual(error as? ShiftScheduleValidationError, .emptyCycle)
        }
    }

    func testManualShiftOverridesAutomaticScheduleWithoutChangingCycle() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let overriddenDay = addingDays(2, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { start })

        try store.setShiftSchedule(.makePreset(.twoTwo, starting: start))
        try store.setShift(.night, for: overriddenDay)

        XCTAssertEqual(store.effectiveShift(for: overriddenDay), .night)
        XCTAssertTrue(store.isShiftOverridden(for: overriddenDay))
        XCTAssertEqual(store.effectiveShift(for: addingDays(3, to: start)), .rest)
        XCTAssertEqual(store.effectiveShift(for: addingDays(4, to: start)), .day)
    }

    func testClearingManualShiftReturnsToAutomaticSchedule() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let overriddenDay = addingDays(2, to: start)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { start })

        try store.setShiftSchedule(.makePreset(.twoTwo, starting: start))
        try store.setShift(.night, for: overriddenDay)
        try store.clearShiftOverride(for: overriddenDay)

        XCTAssertEqual(store.effectiveShift(for: overriddenDay), .rest)
        XCTAssertFalse(store.isShiftOverridden(for: overriddenDay))
    }

    func testSchedulePersistsAcrossLaunches() throws {
        let start = date(year: 2026, month: 5, day: 2)
        let storage = MemoryActivityStorage()
        let firstStore = DayPlanStore(storage: storage, todayProvider: { start })

        try firstStore.setShiftSchedule(.makePreset(.twoDayTwoNight, starting: start))
        try firstStore.setShift(.morning, for: addingDays(4, to: start))

        let reloadedStore = DayPlanStore(storage: storage, todayProvider: { start })

        XCTAssertEqual(reloadedStore.shiftSchedule?.preset, .twoDayTwoNight)
        XCTAssertEqual(reloadedStore.effectiveShift(for: addingDays(2, to: start)), .night)
        XCTAssertEqual(reloadedStore.effectiveShift(for: addingDays(4, to: start)), .morning)
    }

    func testStatsSummaryUsesRealActivitiesAcrossLastSevenDays() throws {
        let today = date(year: 2026, month: 5, day: 8)
        let yesterday = addingDays(-1, to: today)
        let twoDaysAgo = addingDays(-2, to: today)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: today)
        try store.add(NewDayActivity(title: "Медитация", timeText: "22:00", detail: "15 мин", category: .personal, icon: "moon.fill", accent: .rose), on: yesterday)
        try store.add(NewDayActivity(title: "Чтение", timeText: "21:00", detail: "30 мин", category: .personal, icon: "book.fill", accent: .rose), on: twoDaysAgo)

        try store.setCompleted(try XCTUnwrap(store.activities(on: today).first?.id), true)
        try store.setCompleted(try XCTUnwrap(store.activities(on: yesterday).first?.id), true)

        let stats = store.statsSummary(endingOn: today)

        XCTAssertEqual(stats.totalActivities, 4)
        XCTAssertEqual(stats.completedActivities, 2)
        XCTAssertEqual(stats.completionPercent, 50)
        XCTAssertEqual(stats.activeDays, 3)
        XCTAssertEqual(stats.busiestDay?.dayID, DayActivity.dayID(for: today))
        XCTAssertEqual(stats.days.count, 7)
    }

    func testStatsSummaryBuildsCategoryAndShiftBreakdown() throws {
        let today = date(year: 2026, month: 5, day: 8)
        let yesterday = addingDays(-1, to: today)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.setShiftSchedule(.makePreset(.twoTwo, starting: yesterday))
        try store.setShift(.night, for: today)
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Медитация", timeText: "22:00", detail: "15 мин", category: .personal, icon: "moon.fill", accent: .rose), on: yesterday)

        let stats = store.statsSummary(endingOn: today, dayCount: 2)

        XCTAssertEqual(stats.categoryStats.first { $0.category == .body }?.totalCount, 1)
        XCTAssertEqual(stats.categoryStats.first { $0.category == .personal }?.totalCount, 1)
        XCTAssertEqual(stats.shiftStats.first { $0.shift == .night }?.dayCount, 1)
        XCTAssertEqual(stats.shiftStats.first { $0.shift == .day }?.dayCount, 1)
    }

    func testStatsCurrentCompletionStreakStopsAtIncompleteOrEmptyDay() throws {
        let today = date(year: 2026, month: 5, day: 8)
        let yesterday = addingDays(-1, to: today)
        let twoDaysAgo = addingDays(-2, to: today)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: yesterday)
        try store.add(NewDayActivity(title: "Медитация", timeText: "22:00", detail: "15 мин", category: .personal, icon: "moon.fill", accent: .rose), on: twoDaysAgo)

        try store.setCompleted(try XCTUnwrap(store.activities(on: today).first?.id), true)
        try store.setCompleted(try XCTUnwrap(store.activities(on: yesterday).first?.id), true)

        XCTAssertEqual(store.statsSummary(endingOn: today).currentCompletionStreak, 2)
    }

    func testStatsSummaryFocusedDayMatchesSelectedEndDate() throws {
        let today = date(year: 2026, month: 5, day: 8)
        let selectedDay = addingDays(-3, to: today)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: selectedDay)

        let stats = store.statsSummary(endingOn: selectedDay)

        XCTAssertEqual(stats.focusedDay?.dayID, DayActivity.dayID(for: selectedDay))
        XCTAssertEqual(stats.focusedDay?.totalCount, 1)
        XCTAssertEqual(stats.totalActivities, 1)
    }

    func testStatsSummaryCanUseCalendarMonthRange() throws {
        let march31 = date(year: 2026, month: 3, day: 31)
        let april1 = date(year: 2026, month: 4, day: 1)
        let april12 = date(year: 2026, month: 4, day: 12)
        let may1 = date(year: 2026, month: 5, day: 1)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { may1 })

        try store.add(NewDayActivity(title: "Март", timeText: "8:00", detail: "Старое", category: .personal, icon: "book.fill", accent: .rose), on: march31)
        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: april1)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: april12)
        try store.add(NewDayActivity(title: "Май", timeText: "9:00", detail: "Новое", category: .personal, icon: "moon.fill", accent: .rose), on: may1)

        let stats = store.statsSummary(from: april1, to: april12)

        XCTAssertEqual(stats.days.count, 12)
        XCTAssertEqual(stats.totalActivities, 2)
        XCTAssertEqual(stats.categoryStats.first { $0.category == .body }?.totalCount, 2)
        XCTAssertEqual(stats.focusedDay?.dayID, DayActivity.dayID(for: april12))
    }

    func testMonthStatsIncludesAutomaticShiftScheduleForWholeMonth() throws {
        let may1 = date(year: 2026, month: 5, day: 1)
        let may2 = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { may2 })

        try store.setShiftSchedule(.makePreset(.twoDayTwoNight, starting: may1))

        let stats = store.statsSummary(forMonthContaining: may2)

        XCTAssertEqual(stats.days.count, 31)
        XCTAssertEqual(stats.shiftStats.reduce(0) { $0 + $1.dayCount }, 31)
        XCTAssertEqual(stats.shiftStats.first { $0.shift == .day }?.dayCount, 11)
        XCTAssertEqual(stats.shiftStats.first { $0.shift == .night }?.dayCount, 10)
        XCTAssertEqual(stats.shiftStats.first { $0.shift == .recovery }?.dayCount, 5)
        XCTAssertEqual(stats.shiftStats.first { $0.shift == .rest }?.dayCount, 5)
    }

    func testClearCompletedActivitiesKeepsOpenActivities() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.add(NewDayActivity(title: "Зал", timeText: "20:00", detail: "Силовая", category: .body, icon: "dumbbell.fill", accent: .lime), on: today)
        try store.setCompleted(try XCTUnwrap(store.activities.first?.id), true)

        try store.clearCompletedActivities()

        XCTAssertEqual(store.activities.map(\.title), ["Зал"])
        XCTAssertEqual(store.summary.totalCount, 1)
        XCTAssertEqual(store.summary.completedCount, 0)
    }

    func testClearCalendarDetailsKeepsActivitiesAndSchedule() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let store = DayPlanStore(storage: MemoryActivityStorage(), todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.setNote("Взять форму", for: today)
        try store.setShift(.night, for: today)
        try store.setShiftSchedule(.makePreset(.twoTwo, starting: today))

        try store.clearCalendarDetails()

        XCTAssertEqual(store.activities.map(\.title), ["Бег"])
        XCTAssertEqual(store.dayDetails, [])
        XCTAssertEqual(store.shiftSchedule?.preset, .twoTwo)
        XCTAssertEqual(store.effectiveShift(for: today), .day)
    }

    func testResetAllDataClearsActivitiesDetailsAndSchedule() throws {
        let today = date(year: 2026, month: 5, day: 2)
        let storage = MemoryActivityStorage()
        let store = DayPlanStore(storage: storage, todayProvider: { today })

        try store.add(NewDayActivity(title: "Бег", timeText: "7:00", detail: "Парк", category: .body, icon: "figure.run", accent: .sky), on: today)
        try store.setNote("Взять форму", for: today)
        try store.setShiftSchedule(.makePreset(.twoTwo, starting: today))

        try store.resetAllData()

        XCTAssertEqual(store.activities, [])
        XCTAssertEqual(store.dayDetails, [])
        XCTAssertNil(store.shiftSchedule)
        XCTAssertEqual(storage.savedActivities, [])
        XCTAssertEqual(storage.savedDayDetails, [])
        XCTAssertNil(storage.savedShiftSchedule)
    }
}

private final class MemoryActivityStorage: DayActivityStorage {
    var savedActivities: [DayActivity] = []
    var activitiesToLoad: [DayActivity] = []
    var savedDayDetails: [DayDetails] = []
    var dayDetailsToLoad: [DayDetails] = []
    var savedShiftSchedule: ShiftSchedule?
    var shiftScheduleToLoad: ShiftSchedule?
    var savedRecurrenceRules: [DayActivityRecurrenceRule] = []
    var recurrenceRulesToLoad: [DayActivityRecurrenceRule] = []
    var savedRecurrenceSkips: [DayActivityRecurrenceSkip] = []
    var recurrenceSkipsToLoad: [DayActivityRecurrenceSkip] = []

    func loadActivities() throws -> [DayActivity] {
        activitiesToLoad
    }

    func saveActivities(_ activities: [DayActivity]) throws {
        savedActivities = activities
        activitiesToLoad = activities
    }

    func loadDayDetails() throws -> [DayDetails] {
        dayDetailsToLoad
    }

    func saveDayDetails(_ dayDetails: [DayDetails]) throws {
        savedDayDetails = dayDetails
        dayDetailsToLoad = dayDetails
    }

    func loadShiftSchedule() throws -> ShiftSchedule? {
        shiftScheduleToLoad
    }

    func saveShiftSchedule(_ shiftSchedule: ShiftSchedule?) throws {
        savedShiftSchedule = shiftSchedule
        shiftScheduleToLoad = shiftSchedule
    }

    func loadRecurrenceRules() throws -> [DayActivityRecurrenceRule] {
        recurrenceRulesToLoad
    }

    func saveRecurrenceRules(_ recurrenceRules: [DayActivityRecurrenceRule]) throws {
        savedRecurrenceRules = recurrenceRules
        recurrenceRulesToLoad = recurrenceRules
    }

    func loadRecurrenceSkips() throws -> [DayActivityRecurrenceSkip] {
        recurrenceSkipsToLoad
    }

    func saveRecurrenceSkips(_ recurrenceSkips: [DayActivityRecurrenceSkip]) throws {
        savedRecurrenceSkips = recurrenceSkips
        recurrenceSkipsToLoad = recurrenceSkips
    }
}

private func date(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}

private func addingDays(_ days: Int, to date: Date) -> Date {
    Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: date)!
}

private func hour(_ hour: Int, minute: Int, on date: Date) -> Date {
    let calendar = testCalendar
    let start = calendar.startOfDay(for: date)
    return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: start)!
}

private var testCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "dayflow.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    isolatedDefaultSuiteNames.insert(suiteName)
    return defaults
}

private var isolatedDefaultSuiteNames: Set<String> = []

private func remove(defaults: UserDefaults) {
    for suiteName in isolatedDefaultSuiteNames {
        defaults.removePersistentDomain(forName: suiteName)
    }
    isolatedDefaultSuiteNames.removeAll()
}
