import Foundation
import UserNotifications

enum DayflowNotificationPermissionState: Equatable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .unknown, .notDetermined, .denied:
            return false
        }
    }

    var title: String {
        switch self {
        case .unknown:
            return "проверяем"
        case .notDetermined:
            return "не включены"
        case .denied:
            return "запрещены"
        case .authorized:
            return "включены"
        case .provisional:
            return "тихий режим"
        case .ephemeral:
            return "временно"
        }
    }

    var subtitle: String {
        switch self {
        case .unknown:
            return "статус уведомлений обновляется"
        case .notDetermined:
            return "Dayflow спросит разрешение при включении"
        case .denied:
            return "включи уведомления в настройках iOS"
        case .authorized:
            return "напоминания будут приходить по плану"
        case .provisional:
            return "iOS показывает уведомления без звука"
        case .ephemeral:
            return "доступ выдан временно системой"
        }
    }
}

protocol DayflowNotificationScheduling {
    func permissionState() async -> DayflowNotificationPermissionState
    func requestAuthorization() async -> Bool
    func replacePendingRequests(with requests: [DayflowNotificationRequestSpec], calendar: Calendar) async throws -> Int
}

struct DayflowUserNotificationScheduler: DayflowNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func permissionState() async -> DayflowNotificationPermissionState {
        let settings = await notificationSettings()
        return DayflowNotificationPermissionState(settings.authorizationStatus)
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func replacePendingRequests(with requests: [DayflowNotificationRequestSpec], calendar: Calendar) async throws -> Int {
        let existingIDs = await pendingRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(DayflowNotificationPlanBuilder.identifierPrefix) }

        if !existingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: existingIDs)
        }

        for request in requests {
            try await add(notificationRequest(from: request, calendar: calendar))
        }

        return requests.count
    }

    private func notificationRequest(from spec: DayflowNotificationRequestSpec, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        content.sound = .default
        content.userInfo = spec.userInfo

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: spec.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: spec.id, content: content, trigger: trigger)
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

@MainActor
final class DayflowNotificationController: ObservableObject {
    @Published private(set) var permissionState: DayflowNotificationPermissionState = .unknown
    @Published private(set) var pendingCount = 0
    @Published private(set) var errorMessage: String?
    @Published var settings: DayflowNotificationSettings

    private let settingsStorage: UserDefaultsNotificationSettingsStorage
    private let scheduler: DayflowNotificationScheduling
    private let calendar: Calendar

    init(
        settingsStorage: UserDefaultsNotificationSettingsStorage = .sharedAppGroupStorage(),
        scheduler: DayflowNotificationScheduling = DayflowUserNotificationScheduler(),
        calendar: Calendar = .current
    ) {
        self.settingsStorage = settingsStorage
        self.scheduler = scheduler
        self.calendar = calendar
        self.settings = settingsStorage.load()
    }

    var isActive: Bool {
        settings.isEnabled && permissionState.allowsScheduling
    }

    var statusTitle: String {
        if settings.isEnabled {
            return permissionState.title
        }

        return "выключены"
    }

    var statusSubtitle: String {
        if settings.isEnabled {
            return permissionState.subtitle
        }

        return "напоминания можно включить с колокольчика"
    }

    func refreshStatus() {
        Task {
            permissionState = await scheduler.permissionState()
        }
    }

    func save(_ nextSettings: DayflowNotificationSettings, store: DayPlanStore) {
        settings = nextSettings
        settingsStorage.save(nextSettings)

        Task {
            await applyCurrentSettings(store: store, shouldRequestPermission: nextSettings.isEnabled)
        }
    }

    func update(store: DayPlanStore, mutate: (inout DayflowNotificationSettings) -> Void) {
        var next = settings
        mutate(&next)
        save(next, store: store)
    }

    func rescheduleIfNeeded(store: DayPlanStore) {
        guard settings.isEnabled else {
            return
        }

        Task {
            await applyCurrentSettings(store: store, shouldRequestPermission: false)
        }
    }

    private func applyCurrentSettings(store: DayPlanStore, shouldRequestPermission: Bool) async {
        permissionState = await scheduler.permissionState()

        if settings.isEnabled && permissionState == .notDetermined && shouldRequestPermission {
            _ = await scheduler.requestAuthorization()
            permissionState = await scheduler.permissionState()
        }

        guard settings.isEnabled else {
            do {
                pendingCount = try await scheduler.replacePendingRequests(with: [], calendar: calendar)
                errorMessage = nil
            } catch {
                errorMessage = "Не удалось отключить напоминания."
            }
            return
        }

        guard permissionState.allowsScheduling else {
            pendingCount = 0
            _ = try? await scheduler.replacePendingRequests(with: [], calendar: calendar)
            errorMessage = permissionState == .denied
                ? "iOS запретила уведомления. Открой настройки iPhone и включи Dayflow."
                : nil
            return
        }

        let plan = DayflowNotificationPlanBuilder.makePlan(
            settings: settings,
            activities: store.activities,
            dayDetails: store.dayDetails,
            shiftSchedule: store.shiftSchedule,
            now: Date(),
            calendar: calendar
        )

        do {
            pendingCount = try await scheduler.replacePendingRequests(with: plan, calendar: calendar)
            errorMessage = nil
        } catch {
            pendingCount = 0
            errorMessage = "Не удалось обновить напоминания."
        }
    }
}

private extension DayflowNotificationPermissionState {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }
}
