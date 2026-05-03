import SwiftUI

struct DayflowCalendarView: View {
    @ObservedObject var store: DayPlanStore
    let contentWidth: CGFloat

    @State private var selectedDate = Date()
    @State private var noteDraft = ""
    @State private var isShowingAddActivity = false
    @State private var isShowingScheduleBuilder = false
    @State private var errorText: String?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                CalendarHero(
                    selectedDate: $selectedDate,
                    days: monthDays,
                    weekdaySymbols: weekdaySymbols,
                    activityCount: { store.activities(on: $0).count },
                    shiftForDay: { store.effectiveShift(for: $0) },
                    contentWidth: contentWidth,
                    onMoveMonth: moveMonth,
                    onSelectToday: selectToday
                )

                DailyActivitiesBlock(
                    selectedDate: selectedDate,
                    activities: selectedActivities,
                    onToggle: toggleCompleted,
                    onDelete: removeActivity,
                    onAdd: { isShowingAddActivity = true }
                )

                ScheduleControlBlock(
                    schedule: store.shiftSchedule,
                    selectedDate: selectedDate,
                    onOpenBuilder: { isShowingScheduleBuilder = true },
                    onClear: clearSchedule
                )

                ShiftPicker(
                    selectedShift: store.effectiveShift(for: selectedDate),
                    isOverridden: store.isShiftOverridden(for: selectedDate),
                    onAuto: clearManualShift,
                    onSelect: { shift in
                        do {
                            try store.setShift(shift, for: selectedDate)
                            errorText = nil
                        } catch {
                            errorText = "Смена не сохранилась."
                        }
                    }
                )

                NotesBlock(
                    note: $noteDraft,
                    errorText: errorText,
                    onSave: saveNote
                )
                .padding(.bottom, 28)
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            syncNote()
        }
        .onChange(of: selectedDate) { _, _ in
            syncNote()
        }
        .sheet(isPresented: $isShowingAddActivity) {
            NewActivitySheet(
                targetDate: selectedDate,
                onSave: { newActivity in
                    try store.add(newActivity, on: selectedDate)
                },
                onSaveRecurring: { newActivity, pattern in
                    try store.addRecurringActivity(newActivity, pattern: pattern, starting: selectedDate)
                },
                onRepeatPreviousDay: repeatPreviousDayIntoSelection
            )
        }
        .sheet(isPresented: $isShowingScheduleBuilder) {
            ScheduleBuilderSheet(
                startDate: selectedDate,
                currentSchedule: store.shiftSchedule,
                onApply: setSchedule
            )
        }
    }

    private var selectedActivities: [DayActivity] {
        store.activities(on: selectedDate)
    }

    private var monthDays: [CalendarDay] {
        CalendarDay.makeMonthGrid(containing: selectedDate, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
    }

    private func toggleCompleted(_ activity: DayActivity) {
        do {
            try store.setCompleted(activity.id, !activity.isCompleted)
        } catch {
            errorText = "Активность не обновилась."
        }
    }

    private func removeActivity(_ activity: DayActivity) {
        do {
            try store.remove(activity.id)
        } catch {
            errorText = "Активность не удалилась."
        }
    }

    private func repeatPreviousDayIntoSelection() throws -> Int {
        let previousDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        return try store.repeatActivities(from: previousDate, to: selectedDate)
    }

    private func saveNote() {
        do {
            try store.setNote(noteDraft, for: selectedDate)
            errorText = nil
        } catch {
            errorText = "Заметку не удалось сохранить."
        }
    }

    private func syncNote() {
        noteDraft = store.details(for: selectedDate).note
        errorText = nil
    }

    private func setSchedule(_ schedule: ShiftSchedule) throws {
        do {
            try store.setShiftSchedule(schedule)
            errorText = nil
        } catch {
            errorText = "График не сохранился."
            throw error
        }
    }

    private func clearSchedule() {
        do {
            try store.clearShiftSchedule()
            errorText = nil
        } catch {
            errorText = "График не отключился."
        }
    }

    private func clearManualShift() {
        do {
            try store.clearShiftOverride(for: selectedDate)
            errorText = nil
        } catch {
            errorText = "Автосмена не вернулась."
        }
    }

    private func moveMonth(by monthOffset: Int) {
        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
            selectedDate = DayflowCalendarMonthNavigator.date(byAddingMonths: monthOffset, to: selectedDate, calendar: calendar)
        }
    }

    private func selectToday() {
        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
            selectedDate = Date()
        }
    }
}

private struct CalendarHero: View {
    @Binding var selectedDate: Date
    let days: [CalendarDay]
    let weekdaySymbols: [String]
    let activityCount: (Date) -> Int
    let shiftForDay: (Date) -> ShiftKind
    let contentWidth: CGFloat
    let onMoveMonth: (Int) -> Void
    let onSelectToday: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(yearText)
                            .font(.dfBodyBold(14))
                            .foregroundStyle(Color.dayflowPaper.opacity(0.72))

                        if !isCurrentMonth {
                            Button(action: onSelectToday) {
                                Text("Сегодня")
                                    .font(.dfBodyBold(11))
                                    .foregroundStyle(Color.dayflowBlack)
                                    .padding(.horizontal, 10)
                                    .frame(height: 24)
                                    .background(Capsule().fill(Color.dayflowLime))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Вернуться к сегодняшнему дню")
                        }
                    }

                    HStack(spacing: 8) {
                        Text(monthText)
                            .font(.dfDisplaySmall(30))
                            .foregroundStyle(Color.dayflowPaper)

                        Text(dayNumberText)
                            .font(.dfDisplaySmall(18))
                            .foregroundStyle(Color.dayflowLime)
                            .padding(.horizontal, 9)
                            .frame(height: 30)
                            .background(Capsule().fill(Color.dayflowPanel.opacity(0.42)))
                            .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                    }
                }

                Spacer()

                CalendarMonthStepper(
                    onPrevious: { onMoveMonth(-1) },
                    onNext: { onMoveMonth(1) }
                )
            }

            HStack(spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.dfBodyBold(11))
                        .foregroundStyle(Color.dayflowPaper.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(days) { day in
                    CalendarDayButton(
                        day: day,
                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDateInToday(day.date),
                        activityCount: activityCount(day.date),
                        shift: shiftForDay(day.date),
                        action: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                selectedDate = day.date
                            }
                        }
                    )
                }
            }
            .id(monthGridID)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.spring(response: 0.44, dampingFraction: 0.86), value: monthGridID)
        }
        .padding(20)
        .frame(width: safeContentWidth)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.270, green: 0.380, blue: 0.930),
                            Color(red: 0.145, green: 0.250, blue: 0.760)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .topTrailing) {
            CalendarOrb()
                .stroke(Color.dayflowPaper.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 8]))
                .frame(width: 162, height: 162)
                .offset(x: 36, y: -48)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.14), lineWidth: 1)
        )
    }

    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedDate)
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: selectedDate).capitalized
    }

    private var dayNumberText: String {
        String(Calendar.current.component(.day, from: selectedDate))
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    private var monthGridID: String {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private var safeContentWidth: CGFloat {
        contentWidth.isFinite ? max(1, contentWidth) : 1
    }
}

private struct CalendarMonthStepper: View {
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            CalendarMonthStepButton(systemName: "chevron.left", action: onPrevious)

            Rectangle()
                .fill(Color.dayflowPaper.opacity(0.12))
                .frame(width: 1, height: 22)

            CalendarMonthStepButton(systemName: "chevron.right", action: onNext)
        }
        .padding(5)
        .background(
            Capsule()
                .fill(Color.dayflowPanel.opacity(0.52))
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        )
        .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.12), lineWidth: 1))
    }
}

private struct CalendarMonthStepButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.dayflowPaper)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.dayflowBlack.opacity(0.24)))
                .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.left" ? "Предыдущий месяц" : "Следующий месяц")
    }
}

private struct CalendarDayButton: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let activityCount: Int
    let shift: ShiftKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .overlay {
                        if !day.isCurrentMonth {
                            Circle()
                                .stroke(Color.dayflowPaper.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                        } else if isToday && !isSelected {
                            Circle()
                                .stroke(Color.dayflowLime.opacity(0.82), lineWidth: 1.5)
                        }
                    }

                Text(day.numberText)
                    .font(.dfBodyBold(13))
                    .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowPaper)
                    .frame(width: 42, height: 42, alignment: .center)
            }
            .frame(width: 42, height: 42)
            .overlay(alignment: .bottom) {
                if activityCount > 0 {
                    Circle()
                        .fill(isSelected ? Color.dayflowBlack.opacity(0.72) : Color.dayflowLime)
                        .frame(width: 5, height: 5)
                        .padding(.bottom, 6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if shift != .none {
                    Text(shift.badgeTitle)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(shift.badgeForeground)
                        .frame(width: 16, height: 13)
                        .background(Capsule().fill(shift.badgeColor))
                        .overlay(Capsule().stroke(Color.dayflowBlack.opacity(0.25), lineWidth: 0.5))
                        .offset(x: 2, y: -1)
                }
            }
            .opacity(day.isCurrentMonth ? 1 : 0.58)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.dayflowLime
        }

        return day.isCurrentMonth ? Color.dayflowPanel.opacity(0.94) : Color.clear
    }
}

private struct DailyActivitiesBlock: View {
    let selectedDate: Date
    let activities: [DayActivity]
    let onToggle: (DayActivity) -> Void
    let onDelete: (DayActivity) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Activities")
                        .font(.dfDisplaySmall(22))
                        .foregroundStyle(Color.dayflowPaper)

                    Text(dateText)
                        .font(.dfBodyBold(12))
                        .foregroundStyle(Color.dayflowMist)
                }

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.dayflowPaper)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.dayflowPanel.opacity(0.84)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить активность")
            }

            if activities.isEmpty {
                Text("На этот день пока ничего нет.")
                    .font(.dfBody(14))
                    .foregroundStyle(Color.dayflowMist)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 12) {
                    ForEach(activities) { activity in
                        CalendarActivityRow(activity: activity, onToggle: onToggle, onDelete: onDelete)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: selectedDate)
    }
}

private struct CalendarActivityRow: View {
    let activity: DayActivity
    let onToggle: (DayActivity) -> Void
    let onDelete: (DayActivity) -> Void

    var body: some View {
        Button {
            onToggle(activity)
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(activity.accent.color)
                        .frame(width: 7, height: 7)

                    Rectangle()
                        .fill(activity.accent.color.opacity(0.32))
                        .frame(width: 1, height: 22)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.dfDisplaySmall(17))
                        .foregroundStyle(activity.isCompleted ? Color.dayflowMist : Color.dayflowPaper)
                        .strikethrough(activity.isCompleted, color: Color.dayflowMist)

                    Text(activity.detail)
                        .font(.dfBody(12))
                        .foregroundStyle(Color.dayflowMist)
                }

                Spacer()

                Text(activity.timeText)
                    .font(.dfBodyBold(13))
                    .foregroundStyle(Color.dayflowMist)

                Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : activity.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(activity.isCompleted ? Color.dayflowLime : Color.dayflowPaper.opacity(0.86))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(activity)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

private struct ScheduleControlBlock: View {
    let schedule: ShiftSchedule?
    let selectedDate: Date
    let onOpenBuilder: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Автографик")
                        .font(.dfDisplaySmall(22))
                        .foregroundStyle(Color.dayflowPaper)

                    Text(statusText)
                        .font(.dfBodyBold(12))
                        .foregroundStyle(schedule == nil ? Color.dayflowMist : Color.dayflowLime)
                }

                Spacer()

                if schedule != nil {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.dayflowPaper)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.dayflowPanel.opacity(0.92)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Отключить автографик")
                }
            }

            Button(action: onOpenBuilder) {
                HStack(spacing: 13) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.dayflowBlack)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.dayflowLime))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule == nil ? "Заполнить график" : "Изменить график")
                            .font(.dfDisplaySmall(18))
                            .foregroundStyle(Color.dayflowPaper)

                        Text("Быстрые 2/2, день-ночь, 5/2 или своя формула")
                            .font(.dfBodyBold(11))
                            .foregroundStyle(Color.dayflowMist)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.dayflowMist)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.dayflowBlack.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let schedule {
                ScheduleCycleStrip(cycle: schedule.cycle)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.dayflowPanel.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1)
        )
    }

    private var statusText: String {
        guard let schedule else {
            return "Старт будет от \(dateText)"
        }

        return "\(schedule.name) · с \(schedule.startDayID)"
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: selectedDate)
    }
}

private struct ScheduleCycleStrip: View {
    let cycle: [ShiftKind]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Array(cycle.prefix(14).enumerated()), id: \.offset) { index, shift in
                    VStack(spacing: 5) {
                        Text("\(index + 1)")
                            .font(.dfBodyBold(10))
                            .foregroundStyle(Color.dayflowMist)

                        Text(shift.badgeTitle)
                            .font(.dfDisplaySmall(13))
                            .foregroundStyle(shift.badgeForeground)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(shift.badgeColor))
                    }
                }
            }
        }
    }
}

private struct ScheduleBuilderSheet: View {
    let startDate: Date
    let onApply: (ShiftSchedule) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var formula: ShiftScheduleFormula
    @State private var selectedPreset: ShiftSchedulePreset?
    @State private var errorText: String?

    private let calendar = Calendar.current
    private let previewCount = 14
    private static let quickPresets: [ShiftSchedulePreset] = [.twoTwo, .dayNightRest, .fiveTwo]

    init(
        startDate: Date,
        currentSchedule: ShiftSchedule?,
        onApply: @escaping (ShiftSchedule) throws -> Void
    ) {
        self.startDate = startDate
        self.onApply = onApply

        let selectedPreset = currentSchedule.flatMap { schedule in
            Self.quickPresets.first { $0 == schedule.preset }
        } ?? (currentSchedule == nil ? .dayNightRest : nil)
        let fallbackCycle = (selectedPreset ?? .dayNightRest).cycle
        let initialCycle: [ShiftKind]
        if let cycle = currentSchedule?.cycle, !cycle.isEmpty {
            initialCycle = cycle
        } else {
            initialCycle = fallbackCycle
        }

        _formula = State(initialValue: ShiftScheduleFormula(cycle: initialCycle))
        _selectedPreset = State(initialValue: selectedPreset)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Заполнить график")
                            .font(.dfDisplay(30))
                            .foregroundStyle(Color.dayflowPaper)

                        Text("Старт: \(startDateText)")
                            .font(.dfDisplaySmall(18))
                            .foregroundStyle(Color.dayflowLime)
                    }
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Быстро")
                            .font(.dfBodyBold(12))
                            .foregroundStyle(Color.dayflowMist)
                            .textCase(.uppercase)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Self.quickPresets) { preset in
                                    ScheduleQuickOptionCard(
                                        preset: preset,
                                        isSelected: selectedPreset == preset,
                                        action: { selectPreset(preset) }
                                    )
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Формула цикла")
                            .font(.dfBodyBold(12))
                            .foregroundStyle(Color.dayflowMist)
                            .textCase(.uppercase)

                        VStack(spacing: 10) {
                            ScheduleCounterRow(
                                title: "Дни",
                                subtitle: "рабочая дневная смена",
                                symbol: "Д",
                                color: Color.dayflowLime,
                                value: countBinding(\.dayCount)
                            )

                            ScheduleCounterRow(
                                title: "Ночи",
                                subtitle: "ночная смена",
                                symbol: "Н",
                                color: Color.dayflowRose,
                                value: countBinding(\.nightCount)
                            )

                            ScheduleCounterRow(
                                title: "Отсыпные",
                                subtitle: "восстановление после ночи",
                                symbol: "О",
                                color: Color.dayflowPaper,
                                value: countBinding(\.recoveryCount)
                            )

                            ScheduleCounterRow(
                                title: "Выходные",
                                subtitle: "свободные дни",
                                symbol: "В",
                                color: Color.dayflowMist,
                                value: countBinding(\.restCount)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Предпросмотр")
                                .font(.dfDisplaySmall(22))
                                .foregroundStyle(Color.dayflowPaper)

                            Spacer()

                            Text(formula.title)
                                .font(.dfBodyBold(12))
                                .foregroundStyle(formula.cycle.isEmpty ? Color.dayflowRose : Color.dayflowLime)
                        }

                        if formula.cycle.isEmpty {
                            Text("Добавь хотя бы один день, ночь, отсыпной или выходной.")
                                .font(.dfBody(14))
                                .foregroundStyle(Color.dayflowMist)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(Color.dayflowPanel.opacity(0.82))
                                )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 9) {
                                    ForEach(previewDays) { day in
                                        SchedulePreviewChip(day: day)
                                    }
                                }
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.dfBodyBold(13))
                            .foregroundStyle(Color.dayflowRose)
                    }

                    Button(action: apply) {
                        HStack {
                            Text(applyTitle)
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
                    .disabled(formula.cycle.isEmpty)
                    .opacity(formula.cycle.isEmpty ? 0.42 : 1)
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
        .presentationDetents([.large])
    }

    private var startDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: startDate)
    }

    private var applyTitle: String {
        if let selectedPreset {
            return "Применить \(selectedPreset.title)"
        }

        return "Применить формулу"
    }

    private var previewDays: [SchedulePreviewDay] {
        let cycle = formula.cycle
        guard !cycle.isEmpty else { return [] }

        return (0..<previewCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            return SchedulePreviewDay(
                id: offset,
                dayText: String(calendar.component(.day, from: date)),
                weekdayText: weekdayText(for: date),
                shift: cycle[offset % cycle.count]
            )
        }
    }

    private func countBinding(_ keyPath: WritableKeyPath<ShiftScheduleFormula, Int>) -> Binding<Int> {
        Binding(
            get: { formula[keyPath: keyPath] },
            set: { newValue in
                formula[keyPath: keyPath] = min(max(newValue, 0), 31)
                selectedPreset = nil
                errorText = nil
            }
        )
    }

    private func selectPreset(_ preset: ShiftSchedulePreset) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selectedPreset = preset
            formula = ShiftScheduleFormula(cycle: preset.cycle)
            errorText = nil
        }
    }

    private func apply() {
        do {
            let schedule: ShiftSchedule
            if let selectedPreset {
                schedule = .makePreset(selectedPreset, starting: startDate, calendar: calendar)
            } else {
                schedule = try .makeCustom(formula: formula, starting: startDate, calendar: calendar)
            }

            try onApply(schedule)
            dismiss()
        } catch ShiftScheduleValidationError.emptyCycle {
            errorText = "Формула пустая."
        } catch {
            errorText = "График не сохранился."
        }
    }

    private func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }
}

private struct ScheduleQuickOptionCard: View {
    let preset: ShiftSchedulePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(preset.title)
                        .font(.dfDisplaySmall(21))
                        .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowPaper)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowMist)
                }

                Text(preset.subtitle)
                    .font(.dfBodyBold(11))
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? Color.dayflowBlack.opacity(0.66) : Color.dayflowMist)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    ForEach(Array(preset.cycle.prefix(7).enumerated()), id: \.offset) { _, shift in
                        Circle()
                            .fill(isSelected ? Color.dayflowBlack.opacity(0.34) : shift.badgeColor)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(14)
            .frame(width: 164, height: 150, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Color.dayflowLime : Color.dayflowPanel.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.dayflowLime.opacity(0.60) : Color.dayflowPaper.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduleCounterRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 13) {
            Text(symbol)
                .font(.dfDisplaySmall(18))
                .foregroundStyle(symbol == "Н" ? Color.dayflowPaper : Color.dayflowBlack)
                .frame(width: 42, height: 42)
                .background(Circle().fill(color))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.dfDisplaySmall(17))
                    .foregroundStyle(Color.dayflowPaper)

                Text(subtitle)
                    .font(.dfBodyBold(11))
                    .foregroundStyle(Color.dayflowMist)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                ScheduleCounterButton(systemName: "minus", isEnabled: value > 0) {
                    value = max(value - 1, 0)
                }

                Text("\(value)")
                    .font(.dfDisplaySmall(18))
                    .foregroundStyle(Color.dayflowPaper)
                    .frame(width: 34, height: 34)

                ScheduleCounterButton(systemName: "plus", isEnabled: value < 31) {
                    value = min(value + 1, 31)
                }
            }
        }
        .padding(14)
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

private struct ScheduleCounterButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(isEnabled ? Color.dayflowPaper : Color.dayflowMist.opacity(0.38))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.dayflowBlack.opacity(0.34)))
                .overlay(Circle().stroke(Color.dayflowPaper.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct SchedulePreviewDay: Identifiable {
    let id: Int
    let dayText: String
    let weekdayText: String
    let shift: ShiftKind
}

private struct SchedulePreviewChip: View {
    let day: SchedulePreviewDay

    var body: some View {
        VStack(spacing: 8) {
            Text(day.weekdayText)
                .font(.dfBodyBold(10))
                .foregroundStyle(Color.dayflowMist)

            Text(day.dayText)
                .font(.dfDisplaySmall(16))
                .foregroundStyle(Color.dayflowPaper)

            Text(day.shift.badgeTitle)
                .font(.dfDisplaySmall(13))
                .foregroundStyle(day.shift.badgeForeground)
                .frame(width: 30, height: 30)
                .background(Circle().fill(day.shift.badgeColor))
        }
        .frame(width: 58, height: 96)
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

private extension ShiftScheduleFormula {
    init(cycle: [ShiftKind]) {
        self.init(
            dayCount: cycle.filter { $0 == .day }.count,
            nightCount: cycle.filter { $0 == .night }.count,
            recoveryCount: cycle.filter { $0 == .recovery }.count,
            restCount: cycle.filter { $0 == .rest }.count
        )
    }
}

private struct ShiftPicker: View {
    let selectedShift: ShiftKind
    let isOverridden: Bool
    let onAuto: () -> Void
    let onSelect: (ShiftKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Смена")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Text(isOverridden ? "\(selectedShift.title) · ручная" : "\(selectedShift.title) · авто")
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowLime)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    Button(action: onAuto) {
                        Text("Авто")
                            .font(.dfBodyBold(13))
                            .foregroundStyle(!isOverridden ? Color.dayflowBlack : Color.dayflowPaper)
                            .padding(.horizontal, 15)
                            .frame(height: 42)
                            .background(Capsule().fill(!isOverridden ? Color.dayflowLime : Color.dayflowPanel.opacity(0.86)))
                            .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    ForEach(ShiftKind.allCases) { shift in
                        let isSelected = isOverridden && selectedShift == shift

                        Button {
                            onSelect(shift)
                        } label: {
                            Text(shift.shortTitle)
                                .font(.dfBodyBold(13))
                                .foregroundStyle(isSelected ? Color.dayflowBlack : Color.dayflowPaper)
                                .padding(.horizontal, 15)
                                .frame(height: 42)
                                .background(Capsule().fill(isSelected ? Color.dayflowLime : Color.dayflowPanel.opacity(0.86)))
                                .overlay(Capsule().stroke(Color.dayflowPaper.opacity(0.10), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct NotesBlock: View {
    @Binding var note: String
    let errorText: String?
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Заметка")
                    .font(.dfDisplaySmall(22))
                    .foregroundStyle(Color.dayflowPaper)

                Spacer()

                Button("Сохранить", action: onSave)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowLime)
            }

            TextEditor(text: $note)
                .font(.dfBody(15))
                .foregroundStyle(Color.dayflowPaper)
                .tint(Color.dayflowLime)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.dayflowPanel.opacity(0.82))
                )
                .overlay(alignment: .topLeading) {
                    if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Мысли, форма, адрес, что взять с собой")
                            .font(.dfBody(15))
                            .foregroundStyle(Color.dayflowMist.opacity(0.70))
                            .padding(.top, 20)
                            .padding(.leading, 18)
                            .allowsHitTesting(false)
                    }
                }

            if let errorText {
                Text(errorText)
                    .font(.dfBodyBold(12))
                    .foregroundStyle(Color.dayflowRose)
            }
        }
    }
}

private struct CalendarOrb: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width.isFinite,
              rect.height.isFinite,
              rect.width > 0,
              rect.height > 0 else {
            return path
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)

        for index in 0..<5 {
            path.addArc(
                center: center,
                radius: CGFloat(26 + index * 17),
                startAngle: .degrees(92),
                endAngle: .degrees(302),
                clockwise: false
            )
        }

        return path
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let isCurrentMonth: Bool

    var id: String {
        DayActivity.dayID(for: date)
    }

    var numberText: String {
        String(Calendar.current.component(.day, from: date))
    }

    static func makeMonthGrid(containing date: Date, calendar: Calendar) -> [CalendarDay] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingCount = (firstWeekday + 5) % 7

        var days: [CalendarDay] = []

        if leadingCount > 0 {
            for offset in stride(from: leadingCount, through: 1, by: -1) {
                let previousDate = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) ?? startOfMonth
                days.append(CalendarDay(date: previousDate, isCurrentMonth: false))
            }
        }

        for day in range {
            var components = calendar.dateComponents([.year, .month], from: startOfMonth)
            components.day = day
            let monthDate = calendar.date(from: components) ?? startOfMonth
            days.append(CalendarDay(date: monthDate, isCurrentMonth: true))
        }

        while days.count % 7 != 0 || days.count < 35 {
            let nextDate = calendar.date(byAdding: .day, value: 1, to: days.last?.date ?? startOfMonth) ?? startOfMonth
            days.append(CalendarDay(date: nextDate, isCurrentMonth: false))
        }

        return Array(days.prefix(42))
    }
}

private extension ShiftKind {
    var badgeTitle: String {
        switch self {
        case .none:
            return ""
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

    var badgeColor: Color {
        switch self {
        case .none:
            return .clear
        case .morning:
            return Color.dayflowSky
        case .day:
            return Color.dayflowLime
        case .night:
            return Color.dayflowRose
        case .recovery:
            return Color.dayflowPaper
        case .rest:
            return Color.dayflowMist
        }
    }

    var badgeForeground: Color {
        switch self {
        case .night:
            return Color.dayflowPaper
        default:
            return Color.dayflowBlack
        }
    }
}
