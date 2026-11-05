import Foundation

/// ゴール配下のステップ進捗
struct StepProgress: Equatable {
    var completed: Int
    var total: Int
    /// 次にやってくる未完了ステップ
    var nextStep: Event?

    var ratio: Double { total == 0 ? 0 : Double(completed) / Double(total) }
}

extension Array where Element == Event {
    /// トップレベルのゴールのみ
    var goals: [Event] { filter(\.isGoal) }

    /// 指定IDの直下のステップ（日付順）
    func children(of id: UUID) -> [Event] {
        filter { $0.parentId == id }.sorted { $0.displayDate < $1.displayDate }
    }

    /// 指定IDの配下すべて（孫以下も含む）のID
    func descendantIds(of id: UUID) -> [UUID] {
        var result: [UUID] = []
        var queue = [id]
        while let current = queue.popLast() {
            let childIds = filter { $0.parentId == current }.map(\.id)
            result.append(contentsOf: childIds)
            queue.append(contentsOf: childIds)
        }
        return result
    }

    /// 直下のステップの進捗。ステップがなければ nil
    func stepProgress(of id: UUID) -> StepProgress? {
        let steps = children(of: id)
        guard !steps.isEmpty else { return nil }
        return StepProgress(
            completed: steps.filter(\.isCompleted).count,
            total: steps.count,
            nextStep: steps.first { !$0.isCompleted }
        )
    }

    /// ルートから指定IDまでの階層の深さ（ゴール=0）
    func depth(of id: UUID) -> Int {
        var depth = 0
        var current = first { $0.id == id }
        while let parentId = current?.parentId {
            depth += 1
            current = first { $0.id == parentId }
        }
        return depth
    }
}
