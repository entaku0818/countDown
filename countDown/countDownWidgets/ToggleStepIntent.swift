import AppIntents
import WidgetKit

/// ウィジェットからステップを完了チェックするインテント（iOS 17 インタラクティブウィジェット）
struct ToggleStepIntent: AppIntent {
    static var title: LocalizedStringResource = "ステップを完了"
    static var isDiscoverable: Bool = false

    @Parameter(title: "ステップID")
    var stepId: String

    init() {}

    init(stepId: UUID) {
        self.stepId = stepId.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: stepId) {
            SharedDataManager.toggleStep(id)
        }
        return .result()
    }
}
