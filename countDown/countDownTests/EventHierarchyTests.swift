import Testing
import Foundation
@testable import countDown

struct EventHierarchyTests {
    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    @Test func goalsExcludeSteps() {
        let goal = Event(title: "結婚式", date: day(100))
        let step = Event(title: "前撮り", date: day(30), parentId: goal.id)
        #expect([goal, step].goals.map(\.id) == [goal.id])
    }

    @Test func childrenAreSortedByDate() {
        let goal = Event(title: "結婚式", date: day(100))
        let late = Event(title: "招待状", date: day(60), parentId: goal.id)
        let early = Event(title: "前撮り", date: day(30), parentId: goal.id)
        #expect([goal, late, early].children(of: goal.id).map(\.title) == ["前撮り", "招待状"])
    }

    @Test func descendantsIncludeGrandchildren() {
        let goal = Event(title: "結婚式", date: day(100))
        let step = Event(title: "前撮り", date: day(30), parentId: goal.id)
        let sub = Event(title: "衣装合わせ", date: day(20), parentId: step.id)
        let other = Event(title: "旅行", date: day(50))
        let ids = Set([goal, step, sub, other].descendantIds(of: goal.id))
        #expect(ids == [step.id, sub.id])
    }

    @Test func stepProgressCountsDirectChildren() {
        let goal = Event(title: "結婚式", date: day(100))
        let done = Event(title: "前撮り", date: day(30), parentId: goal.id, isCompleted: true)
        let todo = Event(title: "招待状", date: day(60), parentId: goal.id)
        let progress = [goal, done, todo].stepProgress(of: goal.id)
        #expect(progress?.completed == 1)
        #expect(progress?.total == 2)
        #expect(progress?.nextStep?.id == todo.id)
        #expect([goal].stepProgress(of: goal.id) == nil)
    }

    @Test func depthOfNestedStep() {
        let goal = Event(title: "結婚式", date: day(100))
        let step = Event(title: "前撮り", date: day(30), parentId: goal.id)
        let sub = Event(title: "衣装合わせ", date: day(20), parentId: step.id)
        #expect([goal, step, sub].depth(of: sub.id) == 2)
    }

    @Test func legacyDataDecodesAsGoal() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","title":"旅行","date":0,"color":"blue","note":""}
        """
        let event = try JSONDecoder().decode(Event.self, from: Data(legacy.utf8))
        #expect(event.isGoal)
        #expect(event.isCompleted == false)
    }

    @Test func roundTripKeepsHierarchy() throws {
        let parent = UUID()
        let step = Event(title: "前撮り", date: day(30), parentId: parent, isCompleted: true)
        let decoded = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(step))
        #expect(decoded.parentId == parent)
        #expect(decoded.isCompleted)
    }
}
