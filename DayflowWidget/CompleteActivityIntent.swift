import AppIntents
import WidgetKit

struct CompleteActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Закрыть активность"
    static var description = IntentDescription("Отмечает активность Dayflow выполненной.")

    @Parameter(title: "Activity ID")
    var activityID: String

    init() {}

    init(activityID: String) {
        self.activityID = activityID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: activityID) else {
            return .result()
        }

        _ = try? DayflowWidgetActionService.completeActivity(id: id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
