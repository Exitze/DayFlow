import SwiftUI
import UIKit
import WidgetKit

enum DayflowTab: CaseIterable {
    case home
    case calendar
    case stats
    case settings

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .calendar:
            return "calendar"
        case .stats:
            return "chart.bar.fill"
        case .settings:
            return "slider.horizontal.3"
        }
    }

    var label: String {
        switch self {
        case .home:
            return "Главная"
        case .calendar:
            return "Календарь"
        case .stats:
            return "Статистика"
        case .settings:
            return "Настройки"
        }
    }
}

struct DayflowHomeView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var store = DayPlanStore()
    @StateObject private var notificationController = DayflowNotificationController()
    @State private var isAlive = false
    @State private var currentDate = Date()
    @State private var selectedTab: DayflowTab = .home
    @State private var selectedFilter: DayActivityCategory = .all
    @State private var isShowingAddActivity = false
    @State private var isShowingNotificationSettings = false
    @State private var isShowingStoreError = false
    @State private var storeErrorMessage = ""
    @AppStorage("dayflow.onboarding.completed") private var hasCompletedOnboarding = false
    @AppStorage("dayflow.settings.liveBackdrop") private var liveBackdrop = true
    @AppStorage("dayflow.settings.showBackdropPhoto") private var showBackdropPhoto = true
    @AppStorage("dayflow.settings.showFineGrid") private var showFineGrid = true

    private let dayTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let safeScreenWidth = proxy.size.width.isFinite ? max(0, proxy.size.width) : 0
            let contentWidth = min(max(safeScreenWidth - 32, 1), 378)
            let today = currentDate
            let visibleActivities = store.activities(on: today, filteredBy: selectedFilter)
            let totalActivities = store.activities(on: today).count
            let todaySummary = store.summary(on: today)

            ZStack {
                DayflowBackdrop(
                    isAlive: liveBackdrop ? isAlive : false,
                    showPhoto: showBackdropPhoto,
                    showGrid: showFineGrid
                )

                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .home:
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 20) {
                                    HomeTopBar(
                                        date: today,
                                        notificationState: notificationController.permissionState,
                                        notificationsEnabled: notificationController.settings.isEnabled,
                                        onNotificationTap: { isShowingNotificationSettings = true }
                                    )
                                        .frame(width: contentWidth)
                                        .padding(.top, 12)

                                    DayPoster(summary: todaySummary)
                                        .frame(width: contentWidth)

                                    FilterRail(filters: DayActivityCategory.allCases, selectedFilter: $selectedFilter)
                                        .frame(width: contentWidth)

                                    AgendaBlock(
                                        activities: visibleActivities,
                                        totalCount: totalActivities,
                                        onToggleCompleted: toggleCompleted,
                                        onDelete: removeActivity,
                                        onAdd: { isShowingAddActivity = true }
                                    )
                                        .frame(width: contentWidth)

                                    QuietFocusPanel(summary: todaySummary)
                                        .frame(width: contentWidth)
                                        .padding(.bottom, 28)
                                }
                                .frame(width: contentWidth)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .scrollBounceBehavior(.basedOnSize)

                        case .calendar:
                            DayflowCalendarView(store: store, contentWidth: contentWidth)

                        case .stats:
                            DayflowStatsView(store: store, contentWidth: contentWidth)
                                .frame(width: contentWidth)
                                .frame(maxWidth: .infinity, alignment: .center)

                        case .settings:
                            DayflowSettingsView(
                                store: store,
                                notificationController: notificationController,
                                contentWidth: contentWidth,
                                liveBackdrop: $liveBackdrop,
                                showBackdropPhoto: $showBackdropPhoto,
                                showFineGrid: $showFineGrid,
                                onOpenCalendar: { selectedTab = .calendar },
                                onOpenNotifications: { isShowingNotificationSettings = true }
                            )
                                .frame(width: contentWidth)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    DayflowTabBar(selectedTab: $selectedTab)
                        .frame(width: contentWidth)
                        .padding(.bottom, 16)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    isAlive = true
                }
                notificationController.refreshStatus()
                notificationController.rescheduleIfNeeded(store: store)
                refreshCurrentDate()
                markOnboardingCompleteForExistingUsers()
            }
            .onReceive(dayTicker) { tickDate in
                refreshCurrentDate(using: tickDate)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshCurrentDate()
                }
            }
            .onReceive(store.$activities.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onReceive(store.$dayDetails.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onReceive(store.$shiftSchedule.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onReceive(store.$recurrenceRules.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onReceive(store.$recurrenceSkips.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onReceive(store.$habits.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onReceive(store.$habitLogs.dropFirst()) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                notificationController.rescheduleIfNeeded(store: store)
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(isPresented: $isShowingAddActivity) {
                NewActivitySheet(
                    targetDate: currentDate,
                    onSave: { newActivity in
                        try store.add(newActivity, on: currentDate)
                    },
                    onSaveRecurring: { newActivity, pattern in
                        try store.addRecurringActivity(newActivity, pattern: pattern, starting: currentDate)
                    },
                    onSaveHabit: { newActivity, goal, pattern in
                        try store.addHabit(newActivity, goal: goal, pattern: pattern, starting: currentDate)
                    },
                    onRepeatPreviousDay: repeatPreviousDayIntoToday
                )
            }
            .sheet(isPresented: $isShowingNotificationSettings) {
                DayflowNotificationSettingsSheet(store: store, controller: notificationController)
            }
            .fullScreenCover(isPresented: onboardingPresentation) {
                DayflowOnboardingView(
                    today: currentDate,
                    onFinish: completeOnboarding,
                    onSkip: skipOnboarding
                )
            }
            .alert("Не удалось сохранить", isPresented: $isShowingStoreError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(storeErrorMessage)
            }
        }
        .dismissKeyboardOnTapOutside()
    }

    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasCompletedOnboarding = true
                }
            }
        )
    }

    private func toggleCompleted(_ activity: DayActivity) {
        do {
            try store.setCompleted(activity.id, !activity.isCompleted)
        } catch {
            storeErrorMessage = "Изменение не записалось. Попробуй еще раз."
            isShowingStoreError = true
        }
    }

    private func removeActivity(_ activity: DayActivity) {
        do {
            try store.remove(activity.id)
        } catch {
            storeErrorMessage = "Удаление не записалось. Попробуй еще раз."
            isShowingStoreError = true
        }
    }

    private func repeatPreviousDayIntoToday() throws -> Int {
        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        return try store.repeatActivities(from: previousDate, to: currentDate)
    }

    private func handleDeepLink(_ url: URL) {
        guard DayflowDeepLink.isQuickAdd(url) else {
            return
        }

        selectedTab = .home
        refreshCurrentDate()
        isShowingAddActivity = true
    }

    private func refreshCurrentDate(using candidateDate: Date = Date()) {
        let refreshedDate = DayflowCurrentDay.refreshed(currentDate, using: candidateDate)
        if refreshedDate != currentDate {
            currentDate = refreshedDate
        }
    }

    private func completeOnboarding(_ plan: DayflowOnboardingPlan) {
        do {
            try store.applyOnboarding(plan, on: currentDate)
            hasCompletedOnboarding = true
            WidgetCenter.shared.reloadAllTimelines()
            notificationController.rescheduleIfNeeded(store: store)
        } catch {
            storeErrorMessage = "Стартовый день не сохранился. Попробуй еще раз."
            isShowingStoreError = true
        }
    }

    private func skipOnboarding() {
        hasCompletedOnboarding = true
    }

    private func markOnboardingCompleteForExistingUsers() {
        guard !hasCompletedOnboarding else { return }

        if !store.activities.isEmpty || !store.dayDetails.isEmpty || store.shiftSchedule != nil {
            hasCompletedOnboarding = true
        }
    }
}

private enum DayflowOnboardingStep: Int, CaseIterable {
    case intro
    case scenario
    case shift
    case activities
}

private struct DayflowOnboardingView: View {
    let today: Date
    let onFinish: (DayflowOnboardingPlan) -> Void
    let onSkip: () -> Void

    @State private var step: DayflowOnboardingStep = .intro
    @State private var selectedScenario: DayflowOnboardingScenario = .shifts
    @State private var selectedShiftPreset: ShiftSchedulePreset? = .dayNightRest
    @State private var selectedTemplateIDs: Set<String> = Set(["work", "sleep", "water"])

    var body: some View {
        GeometryReader { proxy in
            let geometryWidth = proxy.size.width.isFinite ? proxy.size.width : 390
            let screenWidth = UIScreen.main.bounds.width.isFinite ? UIScreen.main.bounds.width : geometryWidth
            let pageWidth = min(geometryWidth, screenWidth)
            let contentWidth = min(max(pageWidth - 48, 1), 354)

            ZStack(alignment: .topLeading) {
                OnboardingBackdrop()

                VStack(spacing: 0) {
                    OnboardingTopBar(
                        step: step,
                        canGoBack: step != .intro,
                        onBack: goBack,
                        onSkip: onSkip
                    )
                    .frame(width: contentWidth)
                    .padding(.top, 10)

                    TabView(selection: $step) {
                        OnboardingPageFrame(pageWidth: pageWidth, contentWidth: contentWidth) {
                            OnboardingIntroPage(today: today)
                        }
                            .tag(DayflowOnboardingStep.intro)

                        OnboardingPageFrame(pageWidth: pageWidth, contentWidth: contentWidth) {
                            OnboardingScenarioPage(selectedScenario: $selectedScenario)
                        }
                            .tag(DayflowOnboardingStep.scenario)

                        OnboardingPageFrame(pageWidth: pageWidth, contentWidth: contentWidth) {
                            OnboardingShiftPage(selectedPreset: $selectedShiftPreset)
                        }
                            .tag(DayflowOnboardingStep.shift)

                        OnboardingPageFrame(pageWidth: pageWidth, contentWidth: contentWidth) {
                            OnboardingActivityTemplatePage(
                                scenario: selectedScenario,
                                selectedTemplateIDs: $selectedTemplateIDs
                            )
                        }
                        .tag(DayflowOnboardingStep.activities)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)
                    .frame(width: pageWidth)
                    .clipped()

                    OnboardingPrimaryButton(
                        title: primaryButtonTitle,
                        subtitle: primaryButtonSubtitle,
                        isEnabled: canContinue,
                        action: primaryAction
                    )
                    .frame(width: contentWidth)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
                .frame(width: pageWidth)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedScenario) { _, scenario in
            selectedTemplateIDs = Set(DayflowOnboardingCatalog.recommendedTemplates(for: scenario).prefix(3).map(\.id))
            selectedShiftPreset = scenario == .shifts ? .dayNightRest : nil
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .intro:
            return "Настроить мой день"
        case .scenario:
            return selectedScenario == .shifts ? "Выбрать график" : "Выбрать активности"
        case .shift:
            return "Выбрать активности"
        case .activities:
            return "Создать день"
        }
    }

    private var primaryButtonSubtitle: String {
        switch step {
        case .intro:
            return "без аккаунта и лишних настроек"
        case .scenario:
            return selectedScenario.title
        case .shift:
            return selectedShiftPreset?.title ?? "смены можно добавить позже"
        case .activities:
            return "\(selectedTemplateIDs.count) активности на сегодня"
        }
    }

    private var canContinue: Bool {
        step != .activities || !selectedTemplateIDs.isEmpty
    }

    private func primaryAction() {
        switch step {
        case .intro:
            step = .scenario
        case .scenario:
            step = selectedScenario == .shifts ? .shift : .activities
        case .shift:
            step = .activities
        case .activities:
            onFinish(
                DayflowOnboardingPlan(
                    scenario: selectedScenario,
                    shiftPreset: selectedShiftPreset,
                    selectedTemplateIDs: orderedSelectedTemplateIDs
                )
            )
        }
    }

    private func goBack() {
        switch step {
        case .intro:
            break
        case .scenario:
            step = .intro
        case .shift:
            step = .scenario
        case .activities:
            step = selectedScenario == .shifts ? .shift : .scenario
        }
    }

    private var orderedSelectedTemplateIDs: [String] {
        DayflowOnboardingCatalog.recommendedTemplates(for: selectedScenario)
            .map(\.id)
            .filter { selectedTemplateIDs.contains($0) }
    }
}

private struct OnboardingPageFrame<Content: View>: View {
    let pageWidth: CGFloat
    let contentWidth: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            content()
                .frame(width: contentWidth)

            Spacer(minLength: 0)
        }
        .frame(width: pageWidth)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

private struct OnboardingBackdrop: View {
    var body: some View {
        ZStack {
            Color.dayflowBlack

            LinearGradient(
                colors: [
                    Color.dayflowLime.opacity(0.16),
                    Color.dayflowBlack.opacity(0.0),
                    Color.dayflowRose.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            OnboardingArcField()
                .stroke(Color.dayflowLime.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [3, 9]))
                .frame(width: 420, height: 420)
                .offset(x: 120, y: -160)

            OnboardingArcField()
                .stroke(Color.dayflowPaper.opacity(0.055), style: StrokeStyle(lineWidth: 1, dash: [5, 12]))
                .frame(width: 360, height: 360)
                .offset(x: -170, y: 280)
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingTopBar: View {
    let step: DayflowOnboardingStep
    let canGoBack: Bool
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if canGoBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.dayflowPaper)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.dayflowPanel.opacity(0.84)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 40, height: 40)
                }
            }

            OnboardingProgressDots(step: step)

            Spacer()

            Button("Пропустить", action: onSkip)
                .font(.dfBodyBold(13))
                .foregroundStyle(Color.dayflowMist)
        }
    }
}

private struct OnboardingProgressDots: View {
    let step: DayflowOnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DayflowOnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.dayflowLime : Color.dayflowPaper.opacity(0.13))
                    .frame(width: item == step ? 24 : 7, height: 7)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Capsule().fill(Color.dayflowPanel.opacity(0.60)))
        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.08), lineWidth: 1))
    }
}

private struct OnboardingIntroPage: View {
    let today: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Dayflow")
                    .font(.dfDisplay(51))
                    .foregroundStyle(Color.dayflowPaper)
                    .minimumScaleFactor(0.72)

                Text("План дня, смены и личный ритм в одном месте.")
                    .font(.dfDisplaySmall(24))
                    .foregroundStyle(Color.dayflowLime)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            OnboardingHeroPanel(today: today)

            VStack(spacing: 9) {
                OnboardingValueRow(icon: "checkmark.circle.fill", title: "Сегодняшние дела", text: "Бег, зал, работа, фокус и личные задачи без лишнего шума.")
                OnboardingValueRow(icon: "calendar.badge.clock", title: "Смены и восстановление", text: "График влияет на день, Dayflow учитывает это с самого старта.")
                OnboardingValueRow(icon: "bell.badge.fill", title: "Виджеты и напоминания", text: "План виден на экране iPhone и возвращает в нужный момент.")
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)
        }
    }
}

private struct OnboardingHeroPanel: View {
    let today: Date

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
                )

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(dateText)
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowMist)
                        .textCase(.uppercase)

                    Text("0%")
                        .font(.dfDisplay(64))
                        .foregroundStyle(Color.dayflowPaper)

                    HStack(spacing: 8) {
                        OnboardingMiniPill(title: "дела")
                        OnboardingMiniPill(title: "смены")
                        OnboardingMiniPill(title: "ритм")
                    }
                }

                Spacer()

                OnboardingRhythmMark()
                    .frame(width: 104, height: 104)
            }
            .padding(22)
        }
        .frame(height: 196)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: today)
    }
}

private struct OnboardingMiniPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.dfBodyBold(11))
            .foregroundStyle(Color.dayflowBlack)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(Color.dayflowLime))
    }
}

private struct OnboardingValueRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color.dayflowBlack)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.dayflowLime))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.dfDisplaySmall(17))
                    .foregroundStyle(Color.dayflowPaper)

                Text(text)
                    .font(.dfBody(12))
                    .foregroundStyle(Color.dayflowMist)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct OnboardingScenarioPage: View {
    @Binding var selectedScenario: DayflowOnboardingScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingPageTitle(
                eyebrow: "СЦЕНАРИЙ",
                title: "Под что собрать Dayflow?",
                subtitle: "Выбор только настроит первый день. Всё можно поменять позже."
            )

            VStack(spacing: 10) {
                ForEach(DayflowOnboardingScenario.allCases) { scenario in
                    OnboardingScenarioCard(
                        scenario: scenario,
                        isSelected: selectedScenario == scenario,
                        action: { selectedScenario = scenario }
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)
        }
        .padding(.top, 24)
    }
}

private struct OnboardingShiftPage: View {
    @Binding var selectedPreset: ShiftSchedulePreset?

    private let options: [ShiftSchedulePreset?] = [nil, .twoTwo, .dayNightRest, .fiveTwo]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingPageTitle(
                eyebrow: "ГРАФИК",
                title: "Есть смены?",
                subtitle: "Старт графика будет с сегодняшнего дня. Свой сложный цикл можно настроить в календаре."
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, preset in
                    OnboardingShiftOptionCard(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        action: { selectedPreset = preset }
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)
        }
        .padding(.top, 24)
    }
}

private struct OnboardingActivityTemplatePage: View {
    let scenario: DayflowOnboardingScenario
    @Binding var selectedTemplateIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingPageTitle(
                eyebrow: "ПЕРВЫЙ ДЕНЬ",
                title: "Выбери стартовые активности",
                subtitle: "Они сразу появятся на главном экране сегодня."
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(DayflowOnboardingCatalog.recommendedTemplates(for: scenario)) { template in
                    OnboardingTemplateCard(
                        template: template,
                        isSelected: selectedTemplateIDs.contains(template.id),
                        action: { toggle(template.id) }
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)
        }
        .padding(.top, 24)
    }

    private func toggle(_ templateID: String) {
        if selectedTemplateIDs.contains(templateID) {
            selectedTemplateIDs.remove(templateID)
        } else {
            selectedTemplateIDs.insert(templateID)
        }
    }
}

private struct OnboardingPageTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowLime)

            Text(title)
                .font(.dfDisplay(34))
                .foregroundStyle(Color.dayflowPaper)
                .lineLimit(3)

            Text(subtitle)
                .font(.dfBody(14))
                .foregroundStyle(Color.dayflowMist)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingScenarioCard: View {
    let scenario: DayflowOnboardingScenario
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: scenario.icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowLime)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(isSelected ? Color.dayflowLime : Color.dayflowBlack.opacity(0.34)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.title)
                        .font(.dfDisplaySmall(19))
                        .foregroundStyle(Color.dayflowPaper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(scenario.subtitle)
                        .font(.dfBody(12))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(isSelected ? Color.dayflowLime : Color.dayflowMist)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(isSelected ? 0.92 : 0.68))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? Color.dayflowLime.opacity(0.48) : Color.dayflowPaper.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingShiftOptionCard: View {
    let preset: ShiftSchedulePreset?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            cardContent
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 146, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow

            Text(subtitle)
                .font(.dfBodyBold(11))
                .foregroundStyle(subtitleColor)
                .lineLimit(2)

            Spacer(minLength: 0)

            cycleDots
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var titleRow: some View {
        HStack {
            Text(title)
                .font(.dfDisplaySmall(20))
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowMist)
        }
    }

    private var cycleDots: some View {
        HStack(spacing: 4) {
            ForEach(Array(cycle.prefix(7).enumerated()), id: \.offset) { _, shift in
                Circle()
                    .fill(isSelected ? Color.dayflowBlack.opacity(0.34) : shift.statsColor)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var title: String {
        preset?.title ?? "Без смен"
    }

    private var subtitle: String {
        preset?.subtitle ?? "можно настроить позже"
    }

    private var cycle: [ShiftKind] {
        preset?.cycle ?? [.none, .none, .none]
    }

    private var titleColor: Color {
        isSelected ? Color.dayflowBlack : Color.dayflowPaper
    }

    private var subtitleColor: Color {
        isSelected ? Color.dayflowBlack.opacity(0.66) : Color.dayflowMist
    }

    private var backgroundColor: Color {
        isSelected ? Color.dayflowLime : Color.dayflowPanel.opacity(0.74)
    }

    private var borderColor: Color {
        isSelected ? Color.dayflowLime.opacity(0.58) : Color.dayflowPaper.opacity(0.08)
    }
}

private struct OnboardingTemplateCard: View {
    let template: DayflowOnboardingActivityTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(template.accent.color)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.dayflowBlack.opacity(0.30)))

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowMist)
                }

                Text(template.title)
                    .font(.dfDisplaySmall(20))
                    .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowPaper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(template.timeText)
                    .font(.dfBodyBold(13))
                    .foregroundStyle(isSelected ? Color.dayflowBlack.opacity(0.64) : Color.dayflowLime)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Color.dayflowLime : Color.dayflowPanel.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.dayflowLime.opacity(0.58) : Color.dayflowPaper.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dfDisplaySmall(20))

                    Text(subtitle)
                        .font(.dfBodyBold(11))
                        .opacity(0.66)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .black))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.dayflowBlack.opacity(0.16)))
            }
            .foregroundStyle(Color.dayflowBlack)
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(height: 66)
            .background(Capsule().fill(Color.dayflowLime))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

private struct OnboardingRhythmMark: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            for index in 0..<5 {
                let radius = CGFloat(17 + index * 10)
                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(210),
                    endAngle: .degrees(Double(500 - index * 18)),
                    clockwise: false
                )
                context.stroke(
                    path,
                    with: .color(index == 3 ? Color.dayflowLime : Color.dayflowPaper.opacity(0.18)),
                    style: StrokeStyle(lineWidth: index == 3 ? 8 : 4, lineCap: .round)
                )
            }
        }
    }
}

private struct OnboardingArcField: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width.isFinite,
              rect.height.isFinite,
              rect.width > 0,
              rect.height > 0 else {
            return path
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<8 {
            path.addArc(
                center: center,
                radius: CGFloat(28 + index * 22),
                startAngle: .degrees(78),
                endAngle: .degrees(310),
                clockwise: false
            )
        }
        return path
    }
}

private struct DayflowBackdrop: View {
    let isAlive: Bool
    let showPhoto: Bool
    let showGrid: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.dayflowBlack

                if showPhoto {
                    Image("NatureHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: safeBackdropWidth(for: proxy.size.width), height: 560)
                        .clipped()
                        .offset(x: isAlive ? -10 : 10, y: -84)
                        .opacity(0.46)
                        .mask(
                            LinearGradient(
                                colors: [
                                    .black,
                                    .black.opacity(0.92),
                                    .black.opacity(0.24),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }

                LinearGradient(
                    colors: [
                        Color.dayflowBlack.opacity(0.05),
                        Color.dayflowBlack.opacity(0.62),
                        Color.dayflowBlack
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if showGrid {
                    FineGrid()
                        .opacity(0.24)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func safeBackdropWidth(for width: CGFloat) -> CGFloat {
        guard width.isFinite else {
            return 88
        }

        return max(88, width + 88)
    }
}

private struct FineGrid: View {
    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite,
                  size.height.isFinite,
                  size.width > 0,
                  size.height > 0 else {
                return
            }

            let step: CGFloat = 54
            var path = Path()

            stride(from: CGFloat(0), through: size.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            stride(from: CGFloat(0), through: size.height, by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(Color.dayflowPaper.opacity(0.045)), lineWidth: 0.65)
        }
        .accessibilityHidden(true)
    }
}

private struct HomeTopBar: View {
    let date: Date
    let notificationState: DayflowNotificationPermissionState
    let notificationsEnabled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dayflow")
                    .font(.dfDisplay(32))
                    .foregroundStyle(Color.dayflowPaper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(formattedDate)
                    .font(.dfBodyBold(13))
                    .foregroundStyle(Color.dayflowMist)
            }

            Spacer()

            Button(action: onNotificationTap) {
                Image(systemName: isActive ? "bell.badge.fill" : "bell")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isActive ? Color.dayflowBlack : Color.dayflowPaper.opacity(0.88))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(isActive ? Color.dayflowLime : Color.dayflowPanel.opacity(0.72)))
                    .overlay(Circle().stroke(isActive ? Color.dayflowLime.opacity(0.34) : Color.dayflowPaper.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Уведомления")
            .accessibilityValue(isActive ? "Включены" : "Выключены")
        }
    }

    private var isActive: Bool {
        notificationsEnabled && notificationState.allowsScheduling
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }
}

private struct DayPoster: View {
    let summary: DayPlanSummary

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Image("NatureHero")
                    .resizable()
                    .scaledToFill()
                    .frame(width: safePosterWidth(for: proxy.size.width), height: 328)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.22),
                        Color.black.opacity(0.78),
                        Color.black.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                PosterLinework()
                    .opacity(0.72)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("План дня")
                                .font(.dfBodyBold(13))
                                .foregroundStyle(Color.dayflowPaper.opacity(0.74))
                                .textCase(.uppercase)

                            Text(summary.headline)
                                .font(.dfDisplay(42))
                                .lineSpacing(-5)
                                .foregroundStyle(Color.dayflowPaper)
                                .minimumScaleFactor(0.76)
                        }

                        Spacer(minLength: 18)

                        VStack(alignment: .trailing, spacing: 7) {
                            Text("\(summary.progressPercent)%")
                                .font(.dfDisplay(25))
                                .foregroundStyle(Color.dayflowLime)

                            Text(summary.totalCount == 0 ? "пусто" : "ритм")
                                .font(.dfBodyBold(12))
                                .foregroundStyle(Color.dayflowPaper.opacity(0.72))
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        PosterMetric(title: summary.firstTimeText ?? "--", caption: "старт")
                        PosterMetric(title: completedMetricText, caption: "готово")
                        PosterMetric(title: summary.lastTimeText ?? "--", caption: "финиш")
                    }
                }
                .padding(22)
            }
        }
        .frame(height: 328)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 32, x: 0, y: 22)
        .accessibilityElement(children: .combine)
    }

    private func safePosterWidth(for width: CGFloat) -> CGFloat {
        guard width.isFinite else {
            return 1
        }

        return max(1, width)
    }

    private var completedMetricText: String {
        summary.totalCount == 0 ? "0" : "\(summary.completedCount)/\(summary.totalCount)"
    }
}

private struct PosterMetric: View {
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.dfDisplaySmall(15))
                .foregroundStyle(Color.dayflowPaper)
                .lineLimit(1)

            Text(caption)
                .font(.dfBodyBold(11))
                .foregroundStyle(Color.dayflowMist)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct PosterLinework: View {
    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite,
                  size.height.isFinite,
                  size.width > 0,
                  size.height > 0 else {
                return
            }

            let origin = CGPoint(x: size.width * 0.74, y: size.height * 0.12)

            for index in 0..<6 {
                var path = Path()
                let radius = CGFloat(82 + index * 20)
                path.addArc(
                    center: origin,
                    radius: radius,
                    startAngle: .degrees(112 + Double(index * 4)),
                    endAngle: .degrees(266 - Double(index * 3)),
                    clockwise: false
                )
                context.stroke(
                    path,
                    with: .color(Color.dayflowLime.opacity(0.22 - Double(index) * 0.024)),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
                )
            }

            var wave = Path()
            wave.move(to: CGPoint(x: -20, y: size.height * 0.62))
            wave.addCurve(
                to: CGPoint(x: size.width + 20, y: size.height * 0.46),
                control1: CGPoint(x: size.width * 0.24, y: size.height * 0.38),
                control2: CGPoint(x: size.width * 0.70, y: size.height * 0.84)
            )
            context.stroke(
                wave,
                with: .color(Color.dayflowPaper.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 9])
            )
        }
        .accessibilityHidden(true)
    }
}

private struct FilterRail: View {
    let filters: [DayActivityCategory]
    @Binding var selectedFilter: DayActivityCategory

    var body: some View {
        HStack(spacing: 8) {
            ForEach(filters) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    Text(filter.title)
                        .font(.dfBodyBold(13))
                        .foregroundStyle(selectedFilter == filter ? Color.dayflowBlack : Color.dayflowMist)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if selectedFilter == filter {
                                Capsule().fill(Color.dayflowLime)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Capsule().fill(Color.dayflowPanel.opacity(0.78)))
        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
    }
}

private struct AgendaBlock: View {
    let activities: [DayActivity]
    let totalCount: Int
    let onToggleCompleted: (DayActivity) -> Void
    let onDelete: (DayActivity) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Расписание")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(counterText)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowMist)
            }

            VStack(spacing: 10) {
                if activities.isEmpty {
                    EmptyAgendaState(onAdd: onAdd)
                } else {
                    ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                        AgendaRow(
                            activity: activity,
                            index: index,
                            onToggleCompleted: onToggleCompleted,
                            onDelete: onDelete
                        )
                    }

                    AddAgendaRow(action: onAdd)
                }
            }
        }
    }

    private var counterText: String {
        guard totalCount > 0 else {
            return "0 активн."
        }

        return activities.count == totalCount
            ? "\(totalCount) активн."
            : "\(activities.count)/\(totalCount) активн."
    }
}

private struct AgendaRow: View {
    let activity: DayActivity
    let index: Int
    let onToggleCompleted: (DayActivity) -> Void
    let onDelete: (DayActivity) -> Void

    var body: some View {
        HStack(spacing: 15) {
            Text(activity.timeText)
                .font(.dfDisplaySmall(23))
                .foregroundStyle(activity.isCompleted ? Color.dayflowMist : Color.dayflowPaper)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(width: 78, alignment: .leading)

            VStack(spacing: 6) {
                Circle()
                    .fill(activity.accent.color)
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(Color.dayflowPaper.opacity(0.12))
                    .frame(width: 1)
            }
            .frame(height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(activity.title)
                    .font(.dfDisplaySmall(activity.title.count > 8 ? 18 : 21))
                    .foregroundStyle(activity.isCompleted ? Color.dayflowMist : Color.dayflowPaper)
                    .strikethrough(activity.isCompleted, color: Color.dayflowMist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                HStack(spacing: 6) {
                    if activity.isHabit {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.dayflowLime)

                        if let habitGoalText = activity.habitGoalText {
                            Text(habitGoalText)
                                .font(.dfBodyBold(11))
                                .foregroundStyle(Color.dayflowLime)
                        }
                    }

                    Text(activity.detail)
                        .font(.dfBody(13))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(1)
                }

                ProgressTrack(progress: activity.isCompleted ? 1 : 0, accent: activity.accent.color)
                    .padding(.top, 4)
            }

            Spacer(minLength: 4)

            Button {
                onToggleCompleted(activity)
            } label: {
                Image(systemName: activity.isCompleted ? "checkmark" : activity.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(activity.isCompleted ? Color.dayflowBlack : Color.dayflowPaper)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(activity.isCompleted ? Color.dayflowLime : activity.accent.color.opacity(0.22)))
                    .overlay(Circle().stroke(activity.accent.color.opacity(0.36), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activity.isCompleted ? "Вернуть активность" : "Отметить активность")
        }
        .padding(.horizontal, 15)
        .frame(height: 96)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.88))
        )
        .overlay(alignment: .trailing) {
            RowLinework()
                .stroke(Color.dayflowRose.opacity(0.20), lineWidth: 0.75)
                .frame(width: 118, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            onToggleCompleted(activity)
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete(activity)
            } label: {
                Label(activity.isHabit ? "Пропустить" : "Удалить", systemImage: activity.isHabit ? "forward.end.fill" : "trash")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProgressTrack: View {
    let progress: CGFloat
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width.isFinite ? max(0, proxy.size.width) : 0
            let safeProgress = progress.isFinite ? min(max(progress, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.dayflowPaper.opacity(0.10))

                if safeProgress > 0, width > 0 {
                    Capsule()
                        .fill(accent)
                        .frame(width: max(12, width * safeProgress))
                }
            }
        }
        .frame(height: 4)
    }
}

private struct RowLinework: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.maxX - 8, y: rect.minY + 10)

        for index in 0..<5 {
            path.addArc(
                center: CGPoint(x: center.x - CGFloat(index) * 4, y: center.y + CGFloat(index) * 5),
                radius: CGFloat(56 - index * 6),
                startAngle: .degrees(104),
                endAngle: .degrees(282),
                clockwise: false
            )
        }

        return path
    }
}

private struct AddAgendaRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.dayflowBlack)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.dayflowLime))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Добавить")
                        .font(.dfDisplaySmall(19))
                        .foregroundStyle(Color.dayflowPaper)

                    Text("быстрое дело в день")
                        .font(.dfBody(13))
                        .foregroundStyle(Color.dayflowMist)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 82)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [7, 8]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить активность")
    }
}

private struct EmptyAgendaState: View {
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.dayflowLime)

                    Spacer()

                    Text("пусто")
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowMist)
                }

                Text("Собери день")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Text("Добавь первое реальное дело, и экран сам пересчитает план, фильтры и прогресс.")
                    .font(.dfBody(13))
                    .foregroundStyle(Color.dayflowMist)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.74))
            )
            .overlay(alignment: .trailing) {
                RowLinework()
                    .stroke(Color.dayflowRose.opacity(0.18), lineWidth: 0.75)
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить первое дело")
    }
}

private struct QuietFocusPanel: View {
    let summary: DayPlanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Фокус")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(statusText)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowLime)
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(focusTitle)
                        .font(.dfDisplaySmall(23))
                        .foregroundStyle(Color.dayflowPaper)
                        .lineLimit(2)

                    Text(focusCaption)
                        .font(.dfBody(13))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                MiniRhythmMark(progress: Double(summary.progressPercent) / 100)
                    .frame(width: 92, height: 58)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }

    private var statusText: String {
        summary.totalCount == 0 ? "новый день" : "\(summary.completedCount)/\(summary.totalCount)"
    }

    private var focusTitle: String {
        if summary.totalCount == 0 {
            return "Без шума"
        }

        return summary.completedCount == summary.totalCount ? "День закрыт" : "Держи ритм"
    }

    private var focusCaption: String {
        if summary.totalCount == 0 {
            return "Добавь реальные точки дня, остальное пересчитается само."
        }

        return summary.completedCount == summary.totalCount
            ? "Все активности отмечены, прогресс честно дошел до 100%."
            : "Отмечай выполненное, и главный график будет меняться сразу."
    }
}

private struct MiniRhythmMark: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite,
                  size.height.isFinite,
                  size.width > 0,
                  size.height > 0 else {
                return
            }

            let liveValue = CGFloat(max(0.14, min(1, progress)))
            let bars: [CGFloat] = [0.34, 0.58, 0.46, liveValue, 0.66]
            let gap: CGFloat = 6
            let totalGap = gap * CGFloat(max(0, bars.count - 1))
            let barWidth = max(3, (size.width - totalGap) / CGFloat(max(1, bars.count)))

            for (index, value) in bars.enumerated() {
                let height = max(3, size.height * min(max(value, 0), 1))
                let x = CGFloat(index) * (barWidth + gap)
                let rect = CGRect(x: x, y: size.height - height, width: barWidth, height: height)
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                context.fill(path, with: .color(index == 3 ? Color.dayflowLime : Color.dayflowPaper.opacity(0.34)))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DayflowStatsView: View {
    @ObservedObject var store: DayPlanStore
    let contentWidth: CGFloat
    @State private var selectedDate = Date()
    @State private var periodMode: StatsPeriodMode = .week

    private let calendar = Calendar.current

    private var today: Date { Date() }
    private var stats: DayStatsSummary {
        switch periodMode {
        case .week:
            return store.statsSummary(endingOn: selectedDate)
        case .month:
            return store.statsSummary(forMonthContaining: selectedDate)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                StatsHeader(date: selectedDate, isToday: Calendar.current.isDateInToday(selectedDate), stats: stats)
                    .padding(.top, 12)

                StatsPulseHero(stats: stats)

                WeeklyStatsChart(
                    days: stats.days,
                    months: monthOptions,
                    selectedDate: selectedDate,
                    periodMode: periodMode,
                    onSelectMode: selectPeriodMode,
                    onSelectDay: { selectedDate = $0 },
                    onSelectMonth: { selectedDate = $0.endDate }
                )

                StatsCategoryBlock(stats: stats.categoryStats)

                StatsPayrollBlock(
                    summary: payrollSummary,
                    selectedSummary: selectedShiftSummary,
                    periodTitle: payrollPeriodTitle,
                    exportText: payrollExportText
                )

                StatsShiftBlock(
                    shiftStats: stats.shiftStats,
                    selectedDate: selectedDate,
                    selectedShift: store.effectiveShift(for: selectedDate),
                    schedule: store.shiftSchedule
                )
                .padding(.bottom, 28)
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var payrollSummary: ShiftMonthPayrollSummary {
        switch periodMode {
        case .week:
            let start = stats.days.first?.date ?? selectedDate
            let end = stats.days.last?.date ?? selectedDate
            return store.shiftPayrollSummary(from: start, to: end)
        case .month:
            return store.shiftPayrollSummary(forMonthContaining: selectedDate)
        }
    }

    private var selectedShiftSummary: ShiftWorkdaySummary? {
        store.shiftWorkdaySummary(for: selectedDate)
    }

    private var payrollPeriodTitle: String {
        switch periodMode {
        case .week:
            return "7 дней"
        case .month:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: selectedDate).capitalized
        }
    }

    private var payrollExportText: String {
        let summary = payrollSummary
        return [
            "Dayflow · \(payrollPeriodTitle)",
            "\(summary.workedDays) смены",
            "Часы: \(ShiftWorkdaySummary.hoursText(summary.totalMinutes))",
            "Сверх: \(ShiftWorkdaySummary.hoursText(summary.overtimeMinutes))",
            "Оплата: \(Int(summary.estimatedPay.rounded())) ₽",
            "Конфликты: \(summary.conflicts.count)"
        ].joined(separator: "\n")
    }

    private var monthOptions: [StatsMonthOption] {
        let currentMonthStart = monthStart(for: today)

        return (0..<6).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else {
                return nil
            }

            let end = monthEnd(for: start)
            let summary = store.statsSummary(forMonthContaining: start)
            return StatsMonthOption(startDate: start, endDate: end, stats: summary)
        }
    }

    private func selectPeriodMode(_ mode: StatsPeriodMode) {
        withAnimation(.easeInOut(duration: 0.22)) {
            periodMode = mode
        }
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    private func monthEnd(for date: Date) -> Date {
        let start = monthStart(for: date)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? start
    }
}

private enum StatsPeriodMode: CaseIterable, Identifiable {
    case week
    case month

    var id: String {
        switch self {
        case .week:
            return "week"
        case .month:
            return "month"
        }
    }

    var title: String {
        switch self {
        case .week:
            return "7 дней"
        case .month:
            return "Месяцы"
        }
    }
}

private struct StatsMonthOption: Identifiable {
    let startDate: Date
    let endDate: Date
    let stats: DayStatsSummary

    var id: String {
        DayActivity.dayID(for: startDate)
    }

    var totalCount: Int {
        stats.totalActivities
    }

    var completedCount: Int {
        stats.completedActivities
    }

    var completionPercent: Int {
        stats.completionPercent
    }
}

private struct StatsHeader: View {
    let date: Date
    let isToday: Bool
    let stats: DayStatsSummary

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Статистика")
                    .font(.dfDisplay(31))
                    .foregroundStyle(Color.dayflowPaper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(isToday ? "\(periodText) · сегодня" : periodText)
                    .font(.dfBodyBold(13))
                    .foregroundStyle(Color.dayflowMist)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.activeDays)")
                    .font(.dfDisplaySmall(25))
                    .foregroundStyle(Color.dayflowLime)

                Text("активн. дней")
                    .font(.dfBodyBold(11))
                    .foregroundStyle(Color.dayflowMist)
            }
        }
    }

    private var periodText: String {
        guard let first = stats.days.first?.date else {
            return "последние 7 дней"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: first)) - \(formatter.string(from: date))"
    }
}

private struct StatsPulseHero: View {
    let stats: DayStatsSummary

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.78))

            StatsPulseCanvas(days: stats.days)
                .opacity(0.88)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пульс недели")
                            .font(.dfBodyBold(13))
                            .foregroundStyle(Color.dayflowPaper.opacity(0.72))
                            .textCase(.uppercase)

                        Text("\(stats.completionPercent)%")
                            .font(.dfDisplay(58))
                            .foregroundStyle(Color.dayflowPaper)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 18)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text("\(stats.completedActivities)/\(stats.totalActivities)")
                            .font(.dfDisplaySmall(21))
                            .foregroundStyle(Color.dayflowLime)

                        Text("закрыто")
                            .font(.dfBodyBold(12))
                            .foregroundStyle(Color.dayflowMist)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    StatsHeroMetric(title: "\(stats.currentCompletionStreak)", caption: "серия")
                    StatsHeroMetric(title: "\(stats.completedDays)", caption: "идеал")
                    StatsHeroMetric(title: busiestText, caption: "пик")
                }
            }
            .padding(22)
        }
        .frame(height: 286)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 30, x: 0, y: 20)
        .accessibilityElement(children: .combine)
    }

    private var busiestText: String {
        guard let busiestDay = stats.busiestDay else {
            return "0"
        }

        return "\(busiestDay.totalCount)"
    }
}

private struct StatsHeroMetric: View {
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.dfDisplaySmall(18))
                .foregroundStyle(Color.dayflowPaper)
                .lineLimit(1)

            Text(caption)
                .font(.dfBodyBold(11))
                .foregroundStyle(Color.dayflowMist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.dayflowBlack.opacity(0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct StatsPulseCanvas: View {
    let days: [DayStatsDay]

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite,
                  size.height.isFinite,
                  size.width > 0,
                  size.height > 0 else {
                return
            }

            let center = CGPoint(x: size.width * 0.78, y: size.height * 0.16)

            for index in 0..<7 {
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: CGFloat(62 + index * 18),
                    startAngle: .degrees(110),
                    endAngle: .degrees(Double(292 - index * 4)),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(Color.dayflowLime.opacity(0.19 - Double(index) * 0.018)),
                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
                )
            }

            guard days.count > 1 else {
                return
            }

            var flow = Path()
            let values = days.map { CGFloat(max(0.08, Double($0.completionPercent) / 100)) }
            let step = size.width / CGFloat(max(1, values.count - 1))

            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * step
                let y = size.height * (0.76 - value * 0.32)

                if index == 0 {
                    flow.move(to: CGPoint(x: x, y: y))
                } else {
                    let previousX = CGFloat(index - 1) * step
                    let midX = (previousX + x) / 2
                    flow.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: midX, y: size.height * 0.58),
                        control2: CGPoint(x: midX, y: y)
                    )
                }
            }

            context.stroke(
                flow,
                with: .color(Color.dayflowPaper.opacity(0.22)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [5, 9])
            )
        }
        .accessibilityHidden(true)
    }
}

private struct WeeklyStatsChart: View {
    let days: [DayStatsDay]
    let months: [StatsMonthOption]
    let selectedDate: Date
    let periodMode: StatsPeriodMode
    let onSelectMode: (StatsPeriodMode) -> Void
    let onSelectDay: (Date) -> Void
    let onSelectMonth: (StatsMonthOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text(periodMode == .week ? "Выбор дня" : "Выбор месяца")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(selectedText)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowLime)
            }

            StatsPeriodSwitch(selectedMode: periodMode, onSelect: onSelectMode)

            if periodMode == .week {
                HStack(alignment: .center, spacing: 7) {
                    ForEach(days) { day in
                        StatsDayChip(
                            day: day,
                            isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate),
                            onSelect: { onSelectDay(day.date) }
                        )
                    }
                }
                .frame(height: 92)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                StatsMonthStrip(
                    months: months,
                    selectedDate: selectedDate,
                    onSelect: onSelectMonth
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }

    private var selectedText: String {
        if periodMode == .month {
            guard let selectedMonth = months.first(where: { Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .month) }) else {
                return "выбери месяц"
            }

            return "\(selectedMonth.completedCount)/\(selectedMonth.totalCount)"
        }

        guard let selected = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else {
            return "выбери день"
        }

        return "\(selected.completedCount)/\(selected.totalCount)"
    }
}

private struct StatsPeriodSwitch: View {
    let selectedMode: StatsPeriodMode
    let onSelect: (StatsPeriodMode) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StatsPeriodMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    Text(mode.title)
                        .font(.dfBodyBold(12))
                        .foregroundStyle(selectedMode == mode ? Color.dayflowBlack : Color.dayflowMist)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if selectedMode == mode {
                                Capsule().fill(Color.dayflowLime)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.dayflowBlack.opacity(0.34)))
        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.08), lineWidth: 1))
    }
}

private struct StatsMonthStrip: View {
    let months: [StatsMonthOption]
    let selectedDate: Date
    let onSelect: (StatsMonthOption) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(months) { month in
                    StatsMonthPill(
                        month: month,
                        isSelected: Calendar.current.isDate(month.startDate, equalTo: selectedDate, toGranularity: .month),
                        onSelect: { onSelect(month) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct StatsMonthPill: View {
    let month: StatsMonthOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(monthText)
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowPaper)

                    Spacer(minLength: 10)

                    Text("\(month.completionPercent)%")
                        .font(.dfBodyBold(11))
                        .foregroundStyle(isSelected ? Color.dayflowBlack.opacity(0.66) : Color.dayflowLime)
                }

                Text("\(month.completedCount)/\(month.totalCount) закрыто")
                    .font(.dfBodyBold(11))
                    .foregroundStyle(isSelected ? Color.dayflowBlack.opacity(0.66) : Color.dayflowMist)

                ProgressTrack(
                    progress: CGFloat(month.completionPercent) / 100,
                    accent: isSelected ? Color.dayflowBlack : Color.dayflowLime
                )
            }
            .frame(width: 132, height: 104, alignment: .leading)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.dayflowLime : Color.dayflowPanel.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.dayflowLime.opacity(0.82) : Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выбрать \(monthText)")
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLL"
        return formatter.string(from: month.startDate).uppercased()
    }
}

private struct StatsDayChip: View {
    let day: DayStatsDay
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 7) {
                Text(dayNumberText)
                    .font(.dfDisplaySmall(14))
                    .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowPaper)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Color.dayflowLime : Color.dayflowBlack.opacity(0.42)))
                    .overlay(Circle().stroke(Color.dayflowPaper.opacity(isSelected ? 0 : 0.10), lineWidth: 1))

                Text(weekdayText)
                    .font(.dfBodyBold(10))
                    .foregroundStyle(isSelected ? Color.dayflowPaper : Color.dayflowMist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.dayflowPaper.opacity(0.12))

                    if day.totalCount > 0 {
                        Capsule()
                            .fill(progressColor)
                            .frame(width: max(5, 28 * CGFloat(day.completionPercent) / 100))
                    }
                }
                .frame(width: 28, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(isSelected ? Color.dayflowPaper.opacity(0.08) : Color.dayflowPanel.opacity(0.34))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? Color.dayflowLime.opacity(0.72) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выбрать \(weekdayText)")
    }

    private var progressColor: Color {
        if day.isFullyCompleted {
            return Color.dayflowLime
        }

        return day.completedCount > 0 ? Color.dayflowSky : Color.dayflowPaper.opacity(0.28)
    }

    private var dayNumberText: String {
        String(Calendar.current.component(.day, from: day.date))
    }

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: day.date).uppercased()
    }
}

private struct StatsCategoryBlock: View {
    let stats: [DayStatsCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Категории")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text("\(stats.reduce(0) { $0 + $1.totalCount }) дел")
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowMist)
            }

            VStack(spacing: 12) {
                ForEach(stats) { stat in
                    StatsCategoryRow(stat: stat)
                }
            }
        }
    }
}

private struct StatsCategoryRow: View {
    let stat: DayStatsCategory

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: stat.category.defaultIcon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dayflowBlack)
                .frame(width: 42, height: 42)
                .background(Circle().fill(stat.category.defaultAccent.color))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stat.category.title)
                        .font(.dfDisplaySmall(18))
                        .foregroundStyle(Color.dayflowPaper)

                    Spacer()

                    Text("\(stat.completedCount)/\(stat.totalCount)")
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowMist)
                }

                ProgressTrack(
                    progress: CGFloat(stat.completionPercent) / 100,
                    accent: stat.category.defaultAccent.color
                )
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct StatsPayrollBlock: View {
    let summary: ShiftMonthPayrollSummary
    let selectedSummary: ShiftWorkdaySummary?
    let periodTitle: String
    let exportText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Зарплата")
                        .font(.dfDisplaySmall(22))
                        .foregroundStyle(Color.dayflowPaper)

                    Text(periodTitle)
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowLime)
                }

                Spacer()

                ShareLink(item: exportText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.dayflowBlack)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.dayflowLime))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Экспорт зарплаты")
            }

            HStack(spacing: 9) {
                PayrollMetricCell(title: "Оплата", value: "\(Int(summary.estimatedPay.rounded())) ₽", accent: Color.dayflowLime)
                PayrollMetricCell(title: "Часы", value: ShiftWorkdaySummary.hoursText(summary.totalMinutes), accent: Color.dayflowPaper.opacity(0.36))
                PayrollMetricCell(title: "Смены", value: "\(summary.workedDays)", accent: Color.dayflowSky.opacity(0.75))
            }

            HStack(spacing: 9) {
                PayrollMetricCell(title: "Сверх", value: ShiftWorkdaySummary.hoursText(summary.overtimeMinutes), accent: summary.overtimeMinutes > 0 ? Color.dayflowRose : Color.dayflowPaper.opacity(0.22))
                PayrollMetricCell(title: "Конфл.", value: "\(summary.conflicts.count)", accent: summary.conflicts.isEmpty ? Color.dayflowPaper.opacity(0.22) : Color.dayflowRose)
            }

            if let selectedSummary {
                HStack(spacing: 12) {
                    Text(selectedSummary.shift.statsShortTitle)
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(selectedSummary.shift == .night ? Color.dayflowPaper : Color.dayflowBlack)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(selectedSummary.shift.statsColor))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSummary.shift.title)
                            .font(.dfDisplaySmall(18))
                            .foregroundStyle(Color.dayflowPaper)
                            .lineLimit(1)

                        Text("\(selectedSummary.startTimeText)-\(selectedSummary.endTimeText) · \(selectedSummary.totalHoursText)")
                            .font(.dfBodyBold(11))
                            .foregroundStyle(Color.dayflowMist)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(selectedSummary.payText)
                        .font(.dfDisplaySmall(18))
                        .foregroundStyle(Color.dayflowLime)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.dayflowPanel.opacity(0.76))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
                )
            }

            if !summary.conflicts.isEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.dayflowRose)

                    Text(conflictText)
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.dayflowRose.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.dayflowRose.opacity(0.22), lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }

    private var conflictText: String {
        summary.conflicts.prefix(2).map { "\($0.activityTimeText) \($0.activityTitle)" }.joined(separator: " · ")
    }
}

private struct PayrollMetricCell: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.dfBodyBold(10))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            Text(value)
                .font(.dfDisplaySmall(17))
                .foregroundStyle(Color.dayflowPaper)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.dayflowBlack.opacity(0.36))
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .padding(11)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct StatsShiftBlock: View {
    let shiftStats: [DayStatsShift]
    let selectedDate: Date
    let selectedShift: ShiftKind
    let schedule: ShiftSchedule?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Смены")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(schedule?.name ?? "без графика")
                    .font(.dfBodyBold(12))
                    .foregroundStyle(schedule == nil ? Color.dayflowMist : Color.dayflowLime)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dateText)
                        .font(.dfBodyBold(11))
                        .foregroundStyle(Color.dayflowMist)
                        .textCase(.uppercase)

                    Text(selectedShift.title)
                        .font(.dfDisplaySmall(20))
                        .foregroundStyle(Color.dayflowPaper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Text(selectedShift.statsShortTitle)
                    .font(.dfDisplaySmall(18))
                    .foregroundStyle(selectedShift == .night ? Color.dayflowPaper : Color.dayflowBlack)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(selectedShift.statsColor))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )

            if shiftStats.isEmpty {
                Text("Настрой график в календаре, и тут появится распределение смен за неделю.")
                    .font(.dfBody(13))
                    .foregroundStyle(Color.dayflowMist)
                    .padding(.vertical, 4)
            } else {
                HStack(spacing: 9) {
                    ForEach(shiftStats) { stat in
                        VStack(spacing: 6) {
                            Text(stat.shift.statsShortTitle)
                                .font(.dfBodyBold(12))
                                .foregroundStyle(stat.shift == .night ? Color.dayflowPaper : Color.dayflowBlack)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(stat.shift.statsColor))

                            Text("\(stat.dayCount)")
                                .font(.dfDisplaySmall(16))
                                .foregroundStyle(Color.dayflowPaper)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .fill(Color.dayflowPanel.opacity(0.62))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .stroke(Color.dayflowPaper.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var dateText: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Сегодня"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: selectedDate)
    }
}

private struct DayflowSettingsView: View {
    @ObservedObject var store: DayPlanStore
    @ObservedObject var notificationController: DayflowNotificationController
    let contentWidth: CGFloat
    @Binding var liveBackdrop: Bool
    @Binding var showBackdropPhoto: Bool
    @Binding var showFineGrid: Bool
    let onOpenCalendar: () -> Void
    let onOpenNotifications: () -> Void

    @State private var pendingAction: SettingsDataAction?
    @State private var errorText: String?
    @State private var selectedLegalDocument: AppLegalDocument?

    private var today: Date { Date() }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeader()
                    .padding(.top, 12)

                SettingsHero(
                    totalActivities: store.activities.count,
                    completedActivities: store.activities.filter(\.isCompleted).count,
                    dayDetailsCount: store.dayDetails.count,
                    currentShift: store.effectiveShift(for: today)
                )

                SettingsAppearanceBlock(
                    liveBackdrop: $liveBackdrop,
                    showBackdropPhoto: $showBackdropPhoto,
                    showFineGrid: $showFineGrid
                )

                SettingsScheduleBlock(
                    schedule: store.shiftSchedule,
                    currentShift: store.effectiveShift(for: today),
                    onOpenCalendar: onOpenCalendar,
                    onClearSchedule: clearSchedule
                )

                SettingsNotificationsBlock(
                    controller: notificationController,
                    onOpenNotifications: onOpenNotifications,
                    onSendTest: { notificationController.sendTestNotification(store: store) }
                )

                SettingsLegalBlock { document in
                    selectedLegalDocument = document
                }

                SettingsDataBlock(
                    openCount: store.activities.filter { !$0.isCompleted }.count,
                    completedCount: store.activities.filter(\.isCompleted).count,
                    dayDetailsCount: store.dayDetails.count,
                    errorText: errorText,
                    onRequestAction: { pendingAction = $0 }
                )
                .padding(.bottom, 28)
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .confirmationDialog(
            pendingAction?.title ?? "Подтвердить действие",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingAction {
                Button(pendingAction.buttonTitle, role: .destructive) {
                    perform(pendingAction)
                }
            }

            Button("Отмена", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.message ?? "")
        }
        .sheet(item: $selectedLegalDocument) { document in
            LegalDocumentSheet(document: document)
        }
    }

    private func perform(_ action: SettingsDataAction) {
        do {
            switch action {
            case .clearCompleted:
                try store.clearCompletedActivities()
            case .clearCalendarDetails:
                try store.clearCalendarDetails()
            case .resetAll:
                try store.resetAllData()
            }

            errorText = nil
        } catch {
            errorText = "Действие не выполнилось. Попробуй еще раз."
        }

        pendingAction = nil
    }

    private func clearSchedule() {
        do {
            try store.clearShiftSchedule()
            errorText = nil
        } catch {
            errorText = "График не отключился."
        }
    }
}

private enum SettingsDataAction: Identifiable {
    case clearCompleted
    case clearCalendarDetails
    case resetAll

    var id: String {
        switch self {
        case .clearCompleted:
            return "clearCompleted"
        case .clearCalendarDetails:
            return "clearCalendarDetails"
        case .resetAll:
            return "resetAll"
        }
    }

    var title: String {
        switch self {
        case .clearCompleted:
            return "Очистить выполненные?"
        case .clearCalendarDetails:
            return "Очистить календарные детали?"
        case .resetAll:
            return "Сбросить все данные?"
        }
    }

    var message: String {
        switch self {
        case .clearCompleted:
            return "Открытые активности останутся на своих днях."
        case .clearCalendarDetails:
            return "Заметки и ручные смены удалятся, автоматический график останется."
        case .resetAll:
            return "Удалятся активности, заметки, ручные смены и график. Это действие нельзя отменить."
        }
    }

    var buttonTitle: String {
        switch self {
        case .clearCompleted:
            return "Очистить выполненные"
        case .clearCalendarDetails:
            return "Очистить детали"
        case .resetAll:
            return "Сбросить все"
        }
    }
}

private struct SettingsHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Настройки")
                    .font(.dfDisplay(31))
                    .foregroundStyle(Color.dayflowPaper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("локальные данные и внешний вид")
                    .font(.dfBodyBold(13))
                    .foregroundStyle(Color.dayflowMist)
            }

            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.dayflowBlack)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.dayflowLime))
        }
    }
}

private struct SettingsHero: View {
    let totalActivities: Int
    let completedActivities: Int
    let dayDetailsCount: Int
    let currentShift: ShiftKind

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.78))

            SettingsRings()
                .stroke(Color.dayflowLime.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                .frame(width: 220, height: 220)
                .offset(x: 184, y: -72)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dayflow")
                            .font(.dfBodyBold(13))
                            .foregroundStyle(Color.dayflowPaper.opacity(0.72))
                            .textCase(.uppercase)

                        Text(statusTitle)
                            .font(.dfDisplay(38))
                            .lineSpacing(-4)
                            .foregroundStyle(Color.dayflowPaper)
                            .minimumScaleFactor(0.74)
                    }

                    Spacer(minLength: 18)

                    Text(currentShift.statsShortTitle)
                        .font(.dfDisplaySmall(18))
                        .foregroundStyle(currentShift == .night ? Color.dayflowPaper : Color.dayflowBlack)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(currentShift.statsColor))
                }

                HStack(spacing: 10) {
                    StatsHeroMetric(title: "\(totalActivities)", caption: "дел")
                    StatsHeroMetric(title: "\(completedActivities)", caption: "готово")
                    StatsHeroMetric(title: "\(dayDetailsCount)", caption: "детали")
                }
            }
            .padding(22)
        }
        .frame(height: 244)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.12), lineWidth: 1)
        )
    }

    private var statusTitle: String {
        if totalActivities == 0 {
            return "чистый\nстарт"
        }

        return "\(completedActivities)/\(totalActivities)\nзакрыто"
    }
}

private struct SettingsRings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for index in 0..<5 {
            path.addArc(
                center: center,
                radius: CGFloat(34 + index * 22),
                startAngle: .degrees(86),
                endAngle: .degrees(314),
                clockwise: false
            )
        }

        return path
    }
}

private struct SettingsAppearanceBlock: View {
    @Binding var liveBackdrop: Bool
    @Binding var showBackdropPhoto: Bool
    @Binding var showFineGrid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Внешний вид")
                .font(.dfDisplaySmall(22))
                .foregroundStyle(Color.dayflowPaper)

            VStack(spacing: 10) {
                SettingsToggleRow(
                    title: "Живой фон",
                    subtitle: "Мягкое движение обоев",
                    icon: "waveform.path.ecg",
                    isOn: $liveBackdrop
                )

                SettingsToggleRow(
                    title: "Фото на фоне",
                    subtitle: "Горный постер в интерфейсе",
                    icon: "photo.fill",
                    isOn: $showBackdropPhoto
                )

                SettingsToggleRow(
                    title: "Тонкая сетка",
                    subtitle: "Линии навигационного ритма",
                    icon: "square.grid.3x3.fill",
                    isOn: $showFineGrid
                )
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(isOn ? Color.dayflowBlack : Color.dayflowPaper)
                .frame(width: 42, height: 42)
                .background(Circle().fill(isOn ? Color.dayflowLime : Color.dayflowPanel.opacity(0.96)))
                .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.dfDisplaySmall(17))
                    .foregroundStyle(Color.dayflowPaper)

                Text(subtitle)
                    .font(.dfBody(12))
                    .foregroundStyle(Color.dayflowMist)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.dayflowLime)
        }
        .padding(.horizontal, 15)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct SettingsScheduleBlock: View {
    let schedule: ShiftSchedule?
    let currentShift: ShiftKind
    let onOpenCalendar: () -> Void
    let onClearSchedule: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("График")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(schedule?.name ?? "не задан")
                    .font(.dfBodyBold(12))
                    .foregroundStyle(schedule == nil ? Color.dayflowMist : Color.dayflowLime)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Сегодня")
                        .font(.dfBodyBold(11))
                        .foregroundStyle(Color.dayflowMist)
                        .textCase(.uppercase)

                    Text(currentShift.title)
                        .font(.dfDisplaySmall(20))
                        .foregroundStyle(Color.dayflowPaper)
                }

                Spacer()

                Button(action: onOpenCalendar) {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.dayflowBlack)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.dayflowLime))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Открыть календарь")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )

            if schedule != nil {
                Button(action: onClearSchedule) {
                    HStack {
                        Text("Отключить автографик")
                            .font(.dfBodyBold(13))

                        Spacer()

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(Color.dayflowRose)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Capsule().fill(Color.dayflowPanel.opacity(0.62)))
                    .overlay(Capsule().stroke(Color.dayflowRose.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsNotificationsBlock: View {
    @ObservedObject var controller: DayflowNotificationController
    let onOpenNotifications: () -> Void
    let onSendTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Уведомления")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(controller.statusTitle)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(controller.isActive ? Color.dayflowLime : Color.dayflowMist)
            }

            HStack(spacing: 14) {
                Image(systemName: controller.isActive ? "bell.badge.fill" : "bell.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(controller.isActive ? Color.dayflowBlack : Color.dayflowPaper)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(controller.isActive ? Color.dayflowLime : Color.dayflowPanel.opacity(0.96)))
                    .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.isActive ? "\(controller.pendingCount) в расписании" : "Умные напоминания")
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(Color.dayflowPaper)

                    Text(controller.statusSubtitle)
                        .font(.dfBody(12))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Button(action: onOpenNotifications) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.dayflowBlack)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.dayflowLime))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Настроить уведомления")
            }
            .padding(.horizontal, 15)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )

            if controller.isActive {
                Button(action: onSendTest) {
                    HStack {
                        Text("Отправить тест")
                            .font(.dfBodyBold(13))

                        Spacer()

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(Color.dayflowLime)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Capsule().fill(Color.dayflowPanel.opacity(0.62)))
                    .overlay(Capsule().stroke(Color.dayflowLime.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DayflowNotificationSettingsSheet: View {
    @ObservedObject var store: DayPlanStore
    @ObservedObject var controller: DayflowNotificationController

    @Environment(\.dismiss) private var dismiss

    private let leadOptions = [10, 15, 30]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: controller.isActive ? "bell.badge.fill" : "bell.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(controller.isActive ? Color.dayflowBlack : Color.dayflowPaper)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(controller.isActive ? Color.dayflowLime : Color.dayflowPanel.opacity(0.92)))
                            .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))

                        Text("Уведомления")
                            .font(.dfDisplay(30))
                            .foregroundStyle(Color.dayflowPaper)

                        Text(controller.statusSubtitle)
                            .font(.dfBodyBold(13))
                            .foregroundStyle(Color.dayflowMist)
                    }
                    .padding(.top, 10)

                    NotificationMasterRow(
                        title: controller.settings.isEnabled ? "Напоминания включены" : "Напоминания выключены",
                        subtitle: controller.isActive ? "\(controller.pendingCount) уведомлений поставлено из реальных данных" : "утро, дела, смены и вечерний итог",
                        isOn: binding(\.isEnabled)
                    )

                    if controller.settings.isEnabled {
                        VStack(spacing: 10) {
                            NotificationToggleRow(
                                title: "Утренний план",
                                subtitle: "коротко по делам и смене",
                                icon: "sun.max.fill",
                                isOn: binding(\.morningPlanEnabled)
                            )

                            if controller.settings.morningPlanEnabled {
                                NotificationTimeRow(
                                    title: "Время утра",
                                    icon: "clock.fill",
                                    selection: timeBinding(\.morningMinutes)
                                )
                            }

                            NotificationToggleRow(
                                title: "Перед делом",
                                subtitle: "напомнит до бега, зала и других активностей",
                                icon: "figure.run",
                                isOn: binding(\.activityRemindersEnabled)
                            )

                            if controller.settings.activityRemindersEnabled {
                                NotificationLeadRow(
                                    selection: Binding(
                                        get: { controller.settings.activityLeadMinutes },
                                        set: { value in
                                            controller.update(store: store) { $0.activityLeadMinutes = value }
                                        }
                                    ),
                                    options: leadOptions
                                )
                            }

                            NotificationToggleRow(
                                title: "Смена завтра",
                                subtitle: "учитывает автографик и ручные смены",
                                icon: "calendar.badge.clock",
                                isOn: binding(\.shiftReminderEnabled)
                            )

                            if controller.settings.shiftReminderEnabled {
                                NotificationTimeRow(
                                    title: "Время смены",
                                    icon: "briefcase.fill",
                                    selection: timeBinding(\.shiftReminderMinutes)
                                )
                            }

                            NotificationToggleRow(
                                title: "Закрыть день",
                                subtitle: "вечерний остаток открытых дел",
                                icon: "moon.fill",
                                isOn: binding(\.eveningReviewEnabled)
                            )

                            if controller.settings.eveningReviewEnabled {
                                NotificationTimeRow(
                                    title: "Время вечера",
                                    icon: "checkmark.seal.fill",
                                    selection: timeBinding(\.eveningMinutes)
                                )
                            }
                        }
                    }

                    if controller.permissionState == .denied {
                        Button(action: openAppSettings) {
                            HStack {
                                Text("Открыть настройки iOS")
                                    .font(.dfDisplaySmall(17))

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .black))
                            }
                            .foregroundStyle(Color.dayflowBlack)
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.dayflowLime))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        controller.sendTestNotification(store: store)
                    } label: {
                        HStack {
                            Text("Отправить тест")
                                .font(.dfDisplaySmall(17))

                            Spacer()

                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .black))
                        }
                        .foregroundStyle(controller.settings.isEnabled ? Color.dayflowLime : Color.dayflowMist)
                        .padding(.horizontal, 18)
                        .frame(height: 56)
                        .background(Capsule().fill(Color.dayflowPanel.opacity(0.72)))
                        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!controller.settings.isEnabled)
                    .opacity(controller.settings.isEnabled ? 1 : 0.52)

                    if let errorMessage = controller.errorMessage {
                        Text(errorMessage)
                            .font(.dfBodyBold(12))
                            .foregroundStyle(Color.dayflowRose)
                            .lineSpacing(3)
                    }
                }
                .padding(18)
            }
            .background(Color.dayflowBlack.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.dfBodyBold(14))
                    .foregroundStyle(Color.dayflowMist)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            controller.refreshStatus()
            controller.rescheduleIfNeeded(store: store)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<DayflowNotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { controller.settings[keyPath: keyPath] },
            set: { value in
                controller.update(store: store) { settings in
                    settings[keyPath: keyPath] = value
                }
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<DayflowNotificationSettings, Int>) -> Binding<Date> {
        Binding(
            get: { date(fromMinutes: controller.settings[keyPath: keyPath]) },
            set: { newDate in
                controller.update(store: store) { settings in
                    settings[keyPath: keyPath] = minutes(from: newDate)
                }
            }
        )
    }

    private func date(fromMinutes minutes: Int) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

private struct NotificationMasterRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isOn ? "bell.badge.fill" : "bell.slash.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(isOn ? Color.dayflowBlack : Color.dayflowPaper)
                .frame(width: 44, height: 44)
                .background(Circle().fill(isOn ? Color.dayflowLime : Color.dayflowPanel.opacity(0.96)))
                .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.dfDisplaySmall(18))
                    .foregroundStyle(Color.dayflowPaper)

                Text(subtitle)
                    .font(.dfBody(12))
                    .foregroundStyle(Color.dayflowMist)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.dayflowLime)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(isOn ? Color.dayflowBlack : Color.dayflowPaper)
                .frame(width: 42, height: 42)
                .background(Circle().fill(isOn ? Color.dayflowLime : Color.dayflowPanel.opacity(0.96)))
                .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.dfDisplaySmall(16))
                    .foregroundStyle(Color.dayflowPaper)

                Text(subtitle)
                    .font(.dfBody(12))
                    .foregroundStyle(Color.dayflowMist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.dayflowLime)
        }
        .padding(.horizontal, 15)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct NotificationTimeRow: View {
    let title: String
    let icon: String
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.dayflowLime)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.dayflowPanel.opacity(0.88)))

            Text(title)
                .font(.dfBodyBold(13))
                .foregroundStyle(Color.dayflowMist)

            Spacer()

            DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.dayflowLime)
        }
        .padding(.horizontal, 15)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct NotificationLeadRow: View {
    @Binding var selection: Int
    let options: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("За сколько напоминать")
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            Picker("За сколько напоминать", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text("\(option) мин")
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.dayflowLime)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct SettingsLegalBlock: View {
    let onOpenDocument: (AppLegalDocument) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Документы")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text("для релиза")
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowMist)
            }

            VStack(spacing: 10) {
                ForEach(AppLegalDocument.allCases) { document in
                    SettingsDocumentRow(document: document) {
                        onOpenDocument(document)
                    }
                }
            }
        }
    }
}

private struct SettingsDocumentRow: View {
    let document: AppLegalDocument
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: document.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.dayflowBlack)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.dayflowLime))

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(Color.dayflowPaper)

                    Text(document.subtitle)
                        .font(.dfBody(12))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.dayflowMist)
            }
            .padding(.horizontal, 15)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LegalDocumentSheet: View {
    let document: AppLegalDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: document.icon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.dayflowBlack)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Color.dayflowLime))

                        Text(document.title)
                            .font(.dfDisplay(30))
                            .foregroundStyle(Color.dayflowPaper)

                        Text(document.subtitle)
                            .font(.dfBodyBold(13))
                            .foregroundStyle(Color.dayflowMist)
                    }

                    Link(destination: document.publicURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color.dayflowBlack)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.dayflowLime))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Открыть веб-версию")
                                    .font(.dfDisplaySmall(15))
                                    .foregroundStyle(Color.dayflowPaper)

                                Text(document.publicURLString)
                                    .font(.dfBody(11))
                                    .foregroundStyle(Color.dayflowMist)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Color.dayflowMist)
                        }
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.dayflowPanel.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.dayflowLime.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(section.title)
                                .font(.dfDisplaySmall(18))
                                .foregroundStyle(Color.dayflowPaper)

                            Text(section.body)
                                .font(.dfBody(14))
                                .foregroundStyle(Color.dayflowMist)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.dayflowPanel.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
                        )
                    }
                }
                .padding(18)
            }
            .background(Color.dayflowBlack.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.dfBodyBold(14))
                    .foregroundStyle(Color.dayflowMist)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SettingsDataBlock: View {
    let openCount: Int
    let completedCount: Int
    let dayDetailsCount: Int
    let errorText: String?
    let onRequestAction: (SettingsDataAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Данные")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text("\(openCount) открыто")
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowMist)
            }

            VStack(spacing: 10) {
                SettingsDataActionRow(
                    title: "Очистить выполненные",
                    subtitle: "\(completedCount) готовых дел",
                    icon: "checkmark.circle.fill",
                    role: .normal,
                    action: { onRequestAction(.clearCompleted) }
                )
                .disabled(completedCount == 0)
                .opacity(completedCount == 0 ? 0.48 : 1)

                SettingsDataActionRow(
                    title: "Очистить детали календаря",
                    subtitle: "\(dayDetailsCount) заметок и ручных смен",
                    icon: "note.text",
                    role: .normal,
                    action: { onRequestAction(.clearCalendarDetails) }
                )
                .disabled(dayDetailsCount == 0)
                .opacity(dayDetailsCount == 0 ? 0.48 : 1)

                SettingsDataActionRow(
                    title: "Сбросить все",
                    subtitle: "активности, детали и график",
                    icon: "trash.fill",
                    role: .danger,
                    action: { onRequestAction(.resetAll) }
                )
            }

            if let errorText {
                Text(errorText)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowRose)
            }
        }
    }
}

private enum SettingsDataActionRole {
    case normal
    case danger
}

private struct SettingsDataActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let role: SettingsDataActionRole
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(iconForeground)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(iconBackground))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(titleColor)

                    Text(subtitle)
                        .font(.dfBody(12))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.dayflowMist)
            }
            .padding(.horizontal, 15)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var titleColor: Color {
        role == .danger ? Color.dayflowRose : Color.dayflowPaper
    }

    private var iconForeground: Color {
        role == .danger ? Color.dayflowPaper : Color.dayflowBlack
    }

    private var iconBackground: Color {
        role == .danger ? Color.dayflowRose.opacity(0.86) : Color.dayflowLime
    }

    private var borderColor: Color {
        role == .danger ? Color.dayflowRose.opacity(0.20) : Color.dayflowPaper.opacity(0.09)
    }
}

struct NewActivitySheet: View {
    let targetDate: Date
    let onSave: (NewDayActivity) throws -> Void
    let onSaveRecurring: (NewDayActivity, DayActivityRecurrencePattern) throws -> Void
    let onSaveHabit: (NewDayActivity, DayHabitGoal, DayActivityRecurrencePattern) throws -> Void
    let onRepeatPreviousDay: () throws -> Int

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isQuickInputFocused: Bool
    @State private var entryKind: NewActivityEntryKind = .task
    @State private var quickText = ""
    @State private var title = ""
    @State private var detail = ""
    @State private var time = Date()
    @State private var category: DayActivityCategory = .body
    @State private var errorText: String?
    @State private var hasManualCategory = false
    @State private var repeatMode: NewActivityRepeatMode = .none
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedRecurringDayIDs: Set<String> = []
    @State private var selectedShiftKinds: Set<ShiftKind> = []
    @State private var habitGoalValue = 1
    @State private var habitGoalUnit: DayHabitGoalUnit = .count

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    sheetHeader

                    quickInputBlock

                    quickTemplateRail

                    entryKindBlock

                    if entryKind == .task {
                        repeatYesterdayButton
                    }

                    recurrenceBlock

                    if entryKind == .habit {
                        habitGoalBlock
                    }

                    SheetTextField(title: "Название", placeholder: "если нужно поправить", text: $title)
                    SheetTextField(title: "Детали", placeholder: "Парк, 40 мин", text: $detail)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Время")
                            .font(.dfBodyBold(12))
                            .foregroundStyle(Color.dayflowMist)
                            .textCase(.uppercase)

                        HStack {
                            Text(selectedTimeText)
                                .font(.dfDisplaySmall(22))
                                .foregroundStyle(Color.dayflowPaper)

                            Spacer()

                            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.dayflowLime)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.dayflowPanel.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Тип")
                            .font(.dfBodyBold(12))
                            .foregroundStyle(Color.dayflowMist)
                            .textCase(.uppercase)

                        HStack(spacing: 10) {
                            ForEach(DayActivityCategory.creatableCases) { option in
                                Button {
                                    category = option
                                    hasManualCategory = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: option.defaultIcon)
                                            .font(.system(size: 14, weight: .bold))

                                        Text(option.title)
                                            .font(.dfBodyBold(13))
                                    }
                                    .foregroundStyle(category == option ? Color.dayflowBlack : Color.dayflowPaper)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        Capsule().fill(category == option ? Color.dayflowLime : Color.dayflowPanel.opacity(0.82))
                                    )
                                    .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.dfBodyBold(13))
                            .foregroundStyle(Color.dayflowRose)
                            .lineSpacing(3)
                    }

                    Button(action: save) {
                        HStack {
                            Text(entryKind == .habit ? "Добавить привычку" : "Добавить")
                                .font(.dfDisplaySmall(18))

                            Spacer()

                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .black))
                        }
                        .foregroundStyle(Color.dayflowBlack)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(Capsule().fill(Color.dayflowLime))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.42)
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .background(Color.dayflowBlack.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.dfBodyBold(14))
                    .foregroundStyle(Color.dayflowMist)
                }
            }
        }
        .preferredColorScheme(.dark)
        .dismissKeyboardOnTapOutside()
        .onAppear {
            initializeRecurrenceDefaults()
            isQuickInputFocused = true
        }
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Быстрый ввод")
                .font(.dfDisplay(30))
                .foregroundStyle(Color.dayflowPaper)

            HStack(spacing: 8) {
                Text(targetDateText)
                    .font(.dfDisplaySmall(18))
                    .foregroundStyle(Color.dayflowLime)

                Text(selectedTimeText)
                    .font(.dfBodyBold(13))
                    .foregroundStyle(Color.dayflowMist)
            }
        }
        .padding(.top, 10)
    }

    private var quickInputBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Быстро")
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.dayflowBlack)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.dayflowLime))

                TextField("зал 20:00", text: $quickText)
                    .font(.dfDisplaySmall(20))
                    .foregroundStyle(Color.dayflowPaper)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($isQuickInputFocused)
                    .onSubmit(save)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.dayflowLime.opacity(isQuickInputFocused ? 0.38 : 0.12), lineWidth: 1)
            )

            if let previewActivity {
                HStack(spacing: 8) {
                    Image(systemName: previewActivity.icon)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(previewActivity.accent.color)

                    Text("\(previewActivity.title) · \(previewActivity.timeText)")
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowMist)
                        .lineLimit(1)
                }
            }
        }
    }

    private var quickTemplateRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DayflowQuickActivityCatalog.templates) { template in
                    Button {
                        apply(template)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: template.icon)
                                .font(.system(size: 13, weight: .black))

                            Text(template.title)
                                .font(.dfBodyBold(13))
                        }
                        .foregroundStyle(Color.dayflowPaper)
                        .padding(.horizontal, 13)
                        .frame(height: 42)
                        .background(Capsule().fill(Color.dayflowPanel.opacity(0.82)))
                        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var repeatYesterdayButton: some View {
        Button(action: repeatPreviousDay) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Color.dayflowLime)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Повторить вчера")
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(Color.dayflowPaper)

                    Text("скопировать дела на \(targetDateShortText)")
                        .font(.dfBody(12))
                        .foregroundStyle(Color.dayflowMist)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(Color.dayflowPanel.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(Color.dayflowPaper.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var entryKindBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Формат")
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                ForEach(NewActivityEntryKind.allCases) { kind in
                    Button {
                        if kind == .task && entryKind == .habit && repeatMode == .daily {
                            repeatMode = .none
                        }
                        entryKind = kind
                        if kind == .habit && repeatMode == .none {
                            repeatMode = .daily
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 14, weight: .black))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title)
                                    .font(.dfBodyBold(13))
                                Text(kind.subtitle)
                                    .font(.dfBody(10))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(entryKind == kind ? Color.dayflowBlack : Color.dayflowPaper)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .fill(entryKind == kind ? Color.dayflowLime : Color.dayflowPanel.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recurrenceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entryKind == .habit ? "Ритм привычки" : "Повтор")
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(NewActivityRepeatMode.allCases) { mode in
                    Button {
                        repeatMode = mode
                        initializeRecurrenceDefaults()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .black))

                            Text(mode.title)
                                .font(.dfBodyBold(12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                        }
                        .foregroundStyle(repeatMode == mode ? Color.dayflowBlack : Color.dayflowPaper)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            Capsule().fill(repeatMode == mode ? Color.dayflowLime : Color.dayflowPanel.opacity(0.82))
                        )
                        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            recurrenceDetails
        }
    }

    private var habitGoalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цель")
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        habitGoalValue = max(1, habitGoalValue - goalStep)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.dayflowPaper)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.dayflowBlack.opacity(0.72)))
                    }
                    .buttonStyle(.plain)

                    Text("\(habitGoalValue)")
                        .font(.dfDisplaySmall(22))
                        .foregroundStyle(Color.dayflowPaper)
                        .frame(minWidth: 52)

                    Button {
                        habitGoalValue += goalStep
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.dayflowBlack)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.dayflowLime))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.dayflowPanel.opacity(0.86))
                )

                HStack(spacing: 6) {
                    ForEach(DayHabitGoalUnit.allCases) { unit in
                        Button {
                            habitGoalUnit = unit
                            if unit == .minutes && habitGoalValue < 5 {
                                habitGoalValue = 10
                            }
                            if unit == .count && habitGoalValue > 20 {
                                habitGoalValue = 1
                            }
                        } label: {
                            Text(unit.title)
                                .font(.dfBodyBold(11))
                                .foregroundStyle(habitGoalUnit == unit ? Color.dayflowBlack : Color.dayflowPaper)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Capsule().fill(habitGoalUnit == unit ? Color.dayflowLime : Color.dayflowBlack.opacity(0.70)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.dayflowPanel.opacity(0.86))
                )
            }

        }
    }

    @ViewBuilder
    private var recurrenceDetails: some View {
        switch repeatMode {
        case .none, .daily, .afterNight:
            Text(repeatMode.subtitle)
                .font(.dfBody(12))
                .foregroundStyle(Color.dayflowMist)
                .lineSpacing(3)
        case .weekdays:
            HStack(spacing: 7) {
                ForEach(weekdayOptions, id: \.value) { option in
                    Button {
                        toggle(option.value, in: &selectedWeekdays)
                    } label: {
                        Text(option.title)
                            .font(.dfBodyBold(11))
                            .foregroundStyle(selectedWeekdays.contains(option.value) ? Color.dayflowBlack : Color.dayflowPaper)
                            .frame(width: 38, height: 34)
                            .background(Capsule().fill(selectedWeekdays.contains(option.value) ? Color.dayflowLime : Color.dayflowPanel.opacity(0.78)))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .selectedDates:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(candidateRecurringDates, id: \.dayID) { item in
                        Button {
                            toggle(item.dayID, in: &selectedRecurringDayIDs)
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.weekday)
                                    .font(.dfBodyBold(10))
                                Text(item.day)
                                    .font(.dfDisplaySmall(15))
                            }
                            .foregroundStyle(selectedRecurringDayIDs.contains(item.dayID) ? Color.dayflowBlack : Color.dayflowPaper)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(selectedRecurringDayIDs.contains(item.dayID) ? Color.dayflowLime : Color.dayflowPanel.opacity(0.78)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        case .shifts:
            HStack(spacing: 8) {
                ForEach(recurrenceShiftOptions) { shift in
                    Button {
                        toggle(shift, in: &selectedShiftKinds)
                    } label: {
                        Text(shift.shortTitle)
                            .font(.dfBodyBold(11))
                            .foregroundStyle(selectedShiftKinds.contains(shift) ? Color.dayflowBlack : Color.dayflowPaper)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Capsule().fill(selectedShiftKinds.contains(shift) ? Color.dayflowLime : Color.dayflowPanel.opacity(0.78)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedQuickText: String {
        quickText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedQuickText.isEmpty || !trimmedTitle.isEmpty
    }

    private var goalStep: Int {
        habitGoalUnit == .minutes ? 5 : 1
    }

    private var recurrenceShiftOptions: [ShiftKind] {
        [.day, .night, .recovery, .rest]
    }

    private var weekdayOptions: [(value: Int, title: String)] {
        [
            (1, "ПН"),
            (2, "ВТ"),
            (3, "СР"),
            (4, "ЧТ"),
            (5, "ПТ"),
            (6, "СБ"),
            (7, "ВС")
        ]
    }

    private var candidateRecurringDates: [(date: Date, dayID: String, weekday: String, day: String)] {
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "ru_RU")
        weekdayFormatter.dateFormat = "EE"

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "d"

        return (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: targetDate) ?? targetDate
            return (
                date,
                DayActivity.dayID(for: date, calendar: calendar),
                weekdayFormatter.string(from: date).uppercased(),
                dayFormatter.string(from: date)
            )
        }
    }

    private var previewActivity: NewDayActivity? {
        guard !trimmedQuickText.isEmpty else {
            return nil
        }

        return try? DayflowQuickCaptureParser.parse(trimmedQuickText, fallbackTimeText: selectedTimeText)
    }

    private var selectedTimeText: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return String(format: "%d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private var targetDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: targetDate).capitalized
    }

    private var targetDateShortText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: targetDate)
    }

    private func save() {
        do {
            let activity = try makeActivity()
            if entryKind == .habit {
                try onSaveHabit(activity, DayHabitGoal(value: habitGoalValue, unit: habitGoalUnit), try recurrencePattern() ?? .daily)
            } else if let pattern = try recurrencePattern() {
                try onSaveRecurring(activity, pattern)
            } else {
                try onSave(activity)
            }
            dismiss()
        } catch DayActivityValidationError.blankTitle {
            errorText = "Добавь название."
        } catch DayActivityValidationError.invalidTime {
            errorText = "Проверь время."
        } catch DayActivityValidationError.invalidRecurrence {
            errorText = "Выбери дни, даты или смены для повтора."
        } catch {
            errorText = "Не удалось сохранить. Попробуй еще раз."
        }
    }

    private func recurrencePattern() throws -> DayActivityRecurrencePattern? {
        switch repeatMode {
        case .none:
            return nil
        case .daily:
            return .daily
        case .weekdays:
            guard !selectedWeekdays.isEmpty else {
                throw DayActivityValidationError.invalidRecurrence
            }
            return .weekdays(selectedWeekdays.sorted())
        case .selectedDates:
            guard !selectedRecurringDayIDs.isEmpty else {
                throw DayActivityValidationError.invalidRecurrence
            }
            return .selectedDates(selectedRecurringDayIDs.sorted())
        case .shifts:
            guard !selectedShiftKinds.isEmpty else {
                throw DayActivityValidationError.invalidRecurrence
            }
            return .shiftKinds(recurrenceShiftOptions.filter { selectedShiftKinds.contains($0) })
        case .afterNight:
            return .afterNight
        }
    }

    private func makeActivity() throws -> NewDayActivity {
        if !trimmedQuickText.isEmpty {
            let parsed = try DayflowQuickCaptureParser.parse(trimmedQuickText, fallbackTimeText: selectedTimeText)
            let selectedCategory = hasManualCategory ? category : parsed.category
            return NewDayActivity(
                title: trimmedTitle.isEmpty ? parsed.title : title,
                timeText: parsed.timeText,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? parsed.detail : detail,
                category: selectedCategory,
                icon: hasManualCategory ? selectedCategory.defaultIcon : parsed.icon,
                accent: hasManualCategory ? selectedCategory.defaultAccent : parsed.accent
            )
        }

        return NewDayActivity(
            title: title,
            timeText: selectedTimeText,
            detail: detail,
            category: category,
            icon: category.defaultIcon,
            accent: category.defaultAccent
        )
    }

    private func apply(_ template: DayflowQuickActivityTemplate) {
        quickText = "\(template.title.lowercased()) \(template.timeText)"
        title = template.title
        detail = template.detail
        category = template.category
        hasManualCategory = false
        if let minutes = DayActivity.parseTimeText(template.timeText) {
            time = date(fromMinutes: minutes)
        }
    }

    private func repeatPreviousDay() {
        do {
            let count = try onRepeatPreviousDay()
            guard count > 0 else {
                errorText = "Вчера пусто или эти дела уже добавлены."
                return
            }

            dismiss()
        } catch {
            errorText = "Не удалось повторить вчера. Попробуй еще раз."
        }
    }

    private func date(fromMinutes minutes: Int) -> Date {
        let start = Calendar.current.startOfDay(for: targetDate)
        return Calendar.current.date(byAdding: .minute, value: minutes, to: start) ?? targetDate
    }

    private func initializeRecurrenceDefaults() {
        if selectedWeekdays.isEmpty {
            selectedWeekdays = [DayActivityRecurrenceRule.isoWeekday(for: targetDate, calendar: Calendar.current)]
        }

        if selectedRecurringDayIDs.isEmpty {
            selectedRecurringDayIDs = [DayActivity.dayID(for: targetDate)]
        }

        if selectedShiftKinds.isEmpty {
            selectedShiftKinds = [.rest]
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

private enum NewActivityEntryKind: String, CaseIterable, Identifiable {
    case task
    case habit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task:
            return "Дело"
        case .habit:
            return "Привычка"
        }
    }

    var subtitle: String {
        switch self {
        case .task:
            return "разовая задача"
        case .habit:
            return "цель и серия"
        }
    }

    var icon: String {
        switch self {
        case .task:
            return "checkmark.circle.fill"
        case .habit:
            return "repeat.circle.fill"
        }
    }
}

private enum NewActivityRepeatMode: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekdays
    case selectedDates
    case shifts
    case afterNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Без"
        case .daily:
            return "Каждый день"
        case .weekdays:
            return "Дни недели"
        case .selectedDates:
            return "Даты"
        case .shifts:
            return "Смены"
        case .afterNight:
            return "После ночи"
        }
    }

    var subtitle: String {
        switch self {
        case .none:
            return "Добавится только на выбранный день."
        case .daily:
            return "Будет появляться каждый день с выбранной даты."
        case .afterNight:
            return "Появится утром после ночной смены."
        case .weekdays, .selectedDates, .shifts:
            return ""
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "1.circle.fill"
        case .daily:
            return "repeat"
        case .weekdays:
            return "calendar"
        case .selectedDates:
            return "calendar.badge.checkmark"
        case .shifts:
            return "moonphase.first.quarter"
        case .afterNight:
            return "moon.zzz.fill"
        }
    }
}

struct SheetTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.dfBodyBold(12))
                .foregroundStyle(Color.dayflowMist)
                .textCase(.uppercase)

            TextField(placeholder, text: $text)
                .font(.dfDisplaySmall(17))
                .foregroundStyle(Color.dayflowPaper)
                .tint(Color.dayflowLime)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.dayflowPanel.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

private struct DayflowTabBar: View {
    @Binding var selectedTab: DayflowTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DayflowTab.allCases, id: \.self) { item in
                Button {
                    selectedTab = item
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(selectedTab == item ? Color.dayflowBlack : Color.dayflowMist)
                            .frame(width: 46, height: 46)
                            .background {
                                if selectedTab == item {
                                    Circle().fill(Color.dayflowLime)
                                }
                            }

                        Circle()
                            .fill(selectedTab == item ? Color.dayflowLime : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(height: 76)
        .background(
            Capsule()
                .fill(Color.dayflowPanel.opacity(0.94))
                .shadow(color: Color.black.opacity(0.34), radius: 28, x: 0, y: 18)
        )
        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
    }
}

struct PlaceholderTabView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.dayflowBlack)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.dayflowLime))

            Text(title)
                .font(.dfDisplay(36))
                .foregroundStyle(Color.dayflowPaper)

            Text(subtitle)
                .font(.dfBody(15))
                .foregroundStyle(Color.dayflowMist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func dismissKeyboardOnTapOutside() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        func installIfNeeded(from view: UIView) {
            guard let window = view.window, recognizer == nil else {
                return
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.window = window
            self.recognizer = recognizer
        }

        func uninstall() {
            if let recognizer, let window {
                window.removeGestureRecognizer(recognizer)
            }

            recognizer = nil
            window = nil
        }

        @objc private func dismissKeyboard() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !touch.isInsideTextInput
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private extension UITouch {
    var isInsideTextInput: Bool {
        var currentView = view

        while let view = currentView {
            if view is UITextField || view is UITextView {
                return true
            }

            currentView = view.superview
        }

        return false
    }
}

extension DayActivityCategory {
    static let creatableCases: [DayActivityCategory] = [.body, .personal]

    var defaultIcon: String {
        switch self {
        case .body:
            return "figure.run"
        case .personal:
            return "moon.fill"
        case .all:
            return "circle.fill"
        }
    }

    var defaultAccent: ActivityAccent {
        switch self {
        case .body:
            return .sky
        case .personal:
            return .rose
        case .all:
            return .lime
        }
    }
}

extension ActivityAccent {
    var color: Color {
        switch self {
        case .lime:
            return .dayflowLime
        case .sky:
            return .dayflowSky
        case .rose:
            return .dayflowRose
        }
    }
}

extension ShiftKind {
    var shortTitle: String {
        switch self {
        case .none:
            return "Без"
        case .morning:
            return "Утро"
        case .day:
            return "День"
        case .night:
            return "Ночь"
        case .recovery:
            return "Отсып"
        case .rest:
            return "Выход"
        }
    }

    var statsShortTitle: String {
        switch self {
        case .none:
            return "Б"
        case .morning:
            return "У"
        case .day:
            return "Д"
        case .night:
            return "Н"
        case .recovery:
            return "О"
        case .rest:
            return "В"
        }
    }

    var statsColor: Color {
        switch self {
        case .none:
            return Color.dayflowMist
        case .morning:
            return Color.dayflowSky
        case .day:
            return Color.dayflowLime
        case .night:
            return Color.dayflowRose
        case .recovery:
            return Color.dayflowPaper
        case .rest:
            return Color.dayflowMist.opacity(0.86)
        }
    }
}

extension Font {
    static func dfDisplay(_ size: CGFloat) -> Font {
        .custom("Unbounded-Black", size: size)
    }

    static func dfDisplaySmall(_ size: CGFloat) -> Font {
        .custom("Unbounded-SemiBold", size: size)
    }

    static func dfBody(_ size: CGFloat) -> Font {
        .custom("Manrope-Regular", size: size)
    }

    static func dfBodyBold(_ size: CGFloat) -> Font {
        .custom("Manrope-Bold", size: size)
    }
}

extension Color {
    static let dayflowBlack = Color(red: 0.025, green: 0.026, blue: 0.025)
    static let dayflowPanel = Color(red: 0.068, green: 0.074, blue: 0.070)
    static let dayflowPaper = Color(red: 0.930, green: 0.925, blue: 0.880)
    static let dayflowMist = Color(red: 0.660, green: 0.670, blue: 0.630)
    static let dayflowLime = Color(red: 0.800, green: 0.980, blue: 0.135)
    static let dayflowSky = Color(red: 0.350, green: 0.700, blue: 0.940)
    static let dayflowRose = Color(red: 0.920, green: 0.335, blue: 0.390)
}

#Preview {
    DayflowHomeView()
}
