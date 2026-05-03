import SwiftUI
import WidgetKit

struct DayflowWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DayflowWidgetSnapshot
}

struct DayflowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayflowWidgetEntry {
        DayflowWidgetEntry(date: Date(), snapshot: .sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (DayflowWidgetEntry) -> Void) {
        let now = Date()
        let snapshot = context.isPreview ? DayflowWidgetSnapshot.sample(date: now) : DayflowWidgetSnapshotBuilder.snapshot(on: now)
        completion(DayflowWidgetEntry(date: now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayflowWidgetEntry>) -> Void) {
        let now = Date()
        let entry = DayflowWidgetEntry(date: now, snapshot: DayflowWidgetSnapshotBuilder.snapshot(on: now))
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct DayflowPlanWidget: Widget {
    private let kind = "DayflowPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayflowWidgetProvider()) { entry in
            DayflowPlanWidgetView(entry: entry)
        }
        .configurationDisplayName("Dayflow")
        .description("План дня, прогресс и ближайшие активности.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct DayflowShiftWidget: Widget {
    private let kind = "DayflowShiftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayflowWidgetProvider()) { entry in
            DayflowShiftWidgetView(entry: entry)
        }
        .configurationDisplayName("Смена Dayflow")
        .description("Текущая смена и ближайший статус графика.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

private struct DayflowPlanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayflowWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallPlanWidget(snapshot: entry.snapshot)
            case .systemMedium:
                MediumPlanWidget(snapshot: entry.snapshot)
            case .systemLarge:
                LargePlanWidget(snapshot: entry.snapshot)
            case .accessoryRectangular:
                AccessoryPlanWidget(snapshot: entry.snapshot)
            default:
                SmallPlanWidget(snapshot: entry.snapshot)
            }
        }
        .dayflowWidgetBackground()
    }
}

private struct DayflowShiftWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayflowWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                AccessoryShiftWidget(snapshot: entry.snapshot)
            default:
                SmallShiftWidget(snapshot: entry.snapshot)
            }
        }
        .dayflowWidgetBackground()
    }
}

private struct SmallPlanWidget: View {
    let snapshot: DayflowWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: "план дня", value: "\(snapshot.completedCount)/\(snapshot.totalCount)", showsQuickAdd: true)

            ZStack {
                ArcField()
                    .opacity(0.34)

                ProgressOrb(percent: snapshot.progressPercent, size: 70, lineWidth: 8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let activity = snapshot.nextActivities.first {
                ActivityLine(activity: activity, showsButton: false)
            } else {
                EmptyLine(title: "день закрыт", subtitle: "свободно")
            }
        }
        .padding(14)
    }
}

private struct MediumPlanWidget: View {
    let snapshot: DayflowWidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "Dayflow", value: "\(snapshot.completedCount)/\(snapshot.totalCount)", showsQuickAdd: true)

                ProgressOrb(percent: snapshot.progressPercent, size: 88, lineWidth: 9)

                ShiftBadge(shift: snapshot.effectiveShift, scheduleName: snapshot.scheduleName)
            }
            .frame(width: 104, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("ближайшие")
                    .font(.dfWidgetDisplaySmall(16))
                    .foregroundStyle(Color.dayflowWidgetPaper)

                if snapshot.nextActivities.isEmpty {
                    EmptyLine(title: "все закрыто", subtitle: "можно выдохнуть")
                } else {
                    ForEach(snapshot.nextActivities.prefix(3)) { activity in
                        ActivityLine(activity: activity, showsButton: true)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }
}

private struct LargePlanWidget: View {
    let snapshot: DayflowWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("пульс недели")
                        .font(.dfWidgetDisplaySmall(13))
                        .foregroundStyle(Color.dayflowWidgetMist)
                    Text("\(snapshot.progressPercent)%")
                        .font(.dfWidgetDisplay(46))
                        .foregroundStyle(Color.dayflowWidgetPaper)
                }

                Spacer()

                HStack(spacing: 8) {
                    QuickAddWidgetButton(size: 26)
                    ShiftBadge(shift: snapshot.effectiveShift, scheduleName: snapshot.scheduleName)
                }
            }

            WeeklyPulse(days: snapshot.weekDays)

            VStack(alignment: .leading, spacing: 8) {
                Text("план")
                    .font(.dfWidgetDisplaySmall(17))
                    .foregroundStyle(Color.dayflowWidgetPaper)

                if snapshot.nextActivities.isEmpty {
                    EmptyLine(title: "активностей нет", subtitle: "добавь в Dayflow")
                } else {
                    ForEach(snapshot.nextActivities.prefix(3)) { activity in
                        ActivityLine(activity: activity, showsButton: true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct AccessoryPlanWidget: View {
    let snapshot: DayflowWidgetSnapshot

    var body: some View {
        HStack(spacing: 8) {
            ProgressOrb(percent: snapshot.progressPercent, size: 28, lineWidth: 4)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text("Dayflow")
                    .font(.caption.weight(.semibold))
                Text(accessorySubtitle)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }

    private var accessorySubtitle: String {
        if let activity = snapshot.nextActivities.first {
            return activity.title
        }

        return "\(snapshot.completedCount)/\(snapshot.totalCount) закрыто"
    }
}

private struct SmallShiftWidget: View {
    let snapshot: DayflowWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: "смена", value: snapshot.scheduleName ?? "ручн.")

            Spacer(minLength: 0)

            ZStack(alignment: .bottomLeading) {
                ArcField()
                    .opacity(0.28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.effectiveShift.title)
                        .font(.dfWidgetDisplaySmall(24))
                        .foregroundStyle(Color.dayflowWidgetPaper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(snapshot.effectiveShift.widgetSubtitle)
                        .font(.dfWidgetBody(12))
                        .foregroundStyle(Color.dayflowWidgetMist)
                }
            }

            ShiftBadge(shift: snapshot.effectiveShift, scheduleName: snapshot.scheduleName)
        }
        .padding(14)
    }
}

private struct AccessoryShiftWidget: View {
    let snapshot: DayflowWidgetSnapshot

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(snapshot.effectiveShift.widgetColor)
                .frame(width: 8, height: 8)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.effectiveShift.title)
                    .font(.caption.weight(.semibold))
                Text(snapshot.scheduleName ?? "без графика")
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }
}

private struct WidgetHeader: View {
    let title: String
    let value: String
    var showsQuickAdd = false

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.dfWidgetDisplaySmall(13))
                .foregroundStyle(Color.dayflowWidgetMist)
            Spacer(minLength: 8)
            Text(value)
                .font(.dfWidgetDisplaySmall(13))
                .foregroundStyle(Color.dayflowWidgetLime)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            if showsQuickAdd {
                QuickAddWidgetButton(size: 22)
            }
        }
    }
}

private struct QuickAddWidgetButton: View {
    let size: CGFloat

    var body: some View {
        Link(destination: DayflowDeepLink.quickAddURL) {
            Image(systemName: "plus")
                .font(.system(size: max(10, size * 0.48), weight: .black))
                .foregroundStyle(Color.dayflowWidgetBlack)
                .frame(width: size, height: size)
                .background(Color.dayflowWidgetLime, in: Circle())
        }
    }
}

private struct ProgressOrb: View {
    let percent: Int
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.dayflowWidgetPaper.opacity(0.11), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.dayflowWidgetLime,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(percent)%")
                .font(.dfWidgetDisplaySmall(size > 40 ? 18 : 10))
                .foregroundStyle(Color.dayflowWidgetPaper)
                .minimumScaleFactor(0.64)
        }
        .frame(width: size, height: size)
    }

    private var progress: CGFloat {
        CGFloat(max(0, min(100, percent))) / 100
    }
}

private struct ActivityLine: View {
    let activity: DayflowWidgetActivitySnapshot
    let showsButton: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: activity.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(activity.accent.widgetColor)
                .frame(width: 20, height: 20)
                .background(activity.accent.widgetColor.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(activity.title)
                    .font(.dfWidgetBodyBold(13))
                    .foregroundStyle(Color.dayflowWidgetPaper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(activity.timeText)
                    .font(.dfWidgetBody(10))
                    .foregroundStyle(Color.dayflowWidgetMist)
            }

            Spacer(minLength: 4)

            if showsButton {
                Button(intent: CompleteActivityIntent(activityID: activity.id.uuidString)) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.dayflowWidgetBlack)
                        .frame(width: 22, height: 22)
                        .background(Color.dayflowWidgetLime, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.dayflowWidgetPanel.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct EmptyLine: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.dfWidgetBodyBold(13))
                .foregroundStyle(Color.dayflowWidgetPaper)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(subtitle)
                .font(.dfWidgetBody(10))
                .foregroundStyle(Color.dayflowWidgetMist)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.dayflowWidgetPanel.opacity(0.74), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ShiftBadge: View {
    let shift: ShiftKind
    let scheduleName: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(shift.widgetColor)
                .frame(width: 8, height: 8)

            Text(scheduleName.map { "\($0) · \(shift.title)" } ?? shift.title)
                .font(.dfWidgetBodyBold(10))
                .foregroundStyle(Color.dayflowWidgetPaper)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.dayflowWidgetPanel.opacity(0.86), in: Capsule())
    }
}

private struct WeeklyPulse: View {
    let days: [DayflowWidgetDayPulse]

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let height = proxy.size.height
                        let barHeight = max(8, height * CGFloat(max(8, day.completionPercent)) / 100)

                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.dayflowWidgetPaper.opacity(0.11))
                            .overlay(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(day.shift.widgetColor.opacity(day.totalCount == 0 ? 0.35 : 0.9))
                                    .frame(height: barHeight)
                            }
                    }
                    .frame(height: 56)

                    Text(day.weekdayText)
                        .font(.dfWidgetBodyBold(9))
                        .foregroundStyle(Color.dayflowWidgetMist)
                }
            }
        }
        .padding(10)
        .background(Color.dayflowWidgetPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ArcField: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                ArcShape(startAngle: .degrees(205), endAngle: .degrees(520))
                    .stroke(
                        Color.dayflowWidgetLime.opacity(0.18 - Double(index) * 0.025),
                        style: StrokeStyle(lineWidth: CGFloat(5 + index * 4), lineCap: .round)
                    )
                    .padding(CGFloat(index * 12))
            }
        }
    }
}

private struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: max(1, radius),
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

private extension View {
    func dayflowWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            ZStack {
                Color.dayflowWidgetBlack
                LinearGradient(
                    colors: [
                        Color.dayflowWidgetPanel.opacity(0.95),
                        Color.dayflowWidgetBlack,
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private extension DayflowWidgetSnapshot {
    static func sample(date: Date = Date()) -> DayflowWidgetSnapshot {
        let calendar = Calendar.current
        let activities = [
            DayflowWidgetActivitySnapshot(
                id: UUID(),
                title: "Бег",
                timeText: "07:00",
                icon: "figure.run",
                accent: .lime,
                isCompleted: false
            ),
            DayflowWidgetActivitySnapshot(
                id: UUID(),
                title: "Зал",
                timeText: "20:00",
                icon: "dumbbell.fill",
                accent: .rose,
                isCompleted: false
            )
        ]
        let weekDays = (0..<7).map { index in
            let day = calendar.date(byAdding: .day, value: index - 6, to: date) ?? date
            return DayflowWidgetDayPulse(
                dayID: DayActivity.dayID(for: day, calendar: calendar),
                date: day,
                totalCount: index % 3 == 0 ? 0 : 2,
                completedCount: min(2, index),
                completionPercent: [0, 40, 60, 100, 50, 80, 25][index],
                shift: [.rest, .day, .day, .night, .night, .recovery, .rest][index]
            )
        }

        return DayflowWidgetSnapshot(
            date: date,
            totalCount: 3,
            completedCount: 1,
            progressPercent: 33,
            nextActivities: activities,
            effectiveShift: .day,
            scheduleName: "2/2",
            weekDays: weekDays
        )
    }
}

private extension DayflowWidgetActivitySnapshot {
    init(id: UUID, title: String, timeText: String, icon: String, accent: ActivityAccent, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.timeText = timeText
        self.icon = icon
        self.accent = accent
        self.isCompleted = isCompleted
    }
}

private extension DayflowWidgetDayPulse {
    init(dayID: String, date: Date, totalCount: Int, completedCount: Int, completionPercent: Int, shift: ShiftKind) {
        self.dayID = dayID
        self.date = date
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.completionPercent = completionPercent
        self.shift = shift
    }

    var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }
}

private extension ShiftKind {
    var widgetColor: Color {
        switch self {
        case .none:
            return .dayflowWidgetMist
        case .morning:
            return .dayflowWidgetSky
        case .day:
            return .dayflowWidgetLime
        case .night:
            return .dayflowWidgetRose
        case .recovery:
            return .dayflowWidgetPaper
        case .rest:
            return .dayflowWidgetMist
        }
    }

    var widgetSubtitle: String {
        switch self {
        case .none:
            return "график не задан"
        case .morning:
            return "ранний старт"
        case .day:
            return "дневная смена"
        case .night:
            return "ночной режим"
        case .recovery:
            return "отсыпной день"
        case .rest:
            return "выходной"
        }
    }
}

private extension ActivityAccent {
    var widgetColor: Color {
        switch self {
        case .lime:
            return .dayflowWidgetLime
        case .sky:
            return .dayflowWidgetSky
        case .rose:
            return .dayflowWidgetRose
        }
    }
}

private extension Font {
    static func dfWidgetDisplay(_ size: CGFloat) -> Font {
        .custom("Unbounded-Black", size: size)
    }

    static func dfWidgetDisplaySmall(_ size: CGFloat) -> Font {
        .custom("Unbounded-SemiBold", size: size)
    }

    static func dfWidgetBody(_ size: CGFloat) -> Font {
        .custom("Manrope-Regular", size: size)
    }

    static func dfWidgetBodyBold(_ size: CGFloat) -> Font {
        .custom("Manrope-Bold", size: size)
    }
}

private extension Color {
    static let dayflowWidgetBlack = Color(red: 0.025, green: 0.026, blue: 0.025)
    static let dayflowWidgetPanel = Color(red: 0.068, green: 0.074, blue: 0.070)
    static let dayflowWidgetPaper = Color(red: 0.930, green: 0.925, blue: 0.880)
    static let dayflowWidgetMist = Color(red: 0.660, green: 0.670, blue: 0.630)
    static let dayflowWidgetLime = Color(red: 0.800, green: 0.980, blue: 0.135)
    static let dayflowWidgetSky = Color(red: 0.350, green: 0.700, blue: 0.940)
    static let dayflowWidgetRose = Color(red: 0.920, green: 0.335, blue: 0.390)
}
