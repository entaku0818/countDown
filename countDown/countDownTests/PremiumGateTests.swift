import Testing
import Foundation
import ComposableArchitecture
@testable import countDown

@MainActor
struct PremiumGateTests {
    private func store(events: [Event], billingEnabled: Bool = true, isPremium: Bool = false) -> TestStoreOf<CountdownFeature> {
        var state = CountdownFeature.State(events: events)
        state.billingEnabled = billingEnabled
        state.isPremium = isPremium
        let store = TestStore(initialState: state) { CountdownFeature() }
        store.exhaustivity = .off
        return store
    }

    private func goals(_ count: Int) -> [Event] {
        (0..<count).map { Event(title: "ゴール\($0)", date: Date().addingTimeInterval(86400 * 10)) }
    }

    @Test func freeUserHitsGoalLimit() async {
        let store = store(events: goals(FreePlanLimit.goals))
        await store.send(.addButtonTapped)
        await store.receive(\.showPaywall) {
            $0.paywall = PaywallFeature.State(reason: .goalLimit)
        }
    }

    @Test func premiumUserCanAddMoreGoals() async {
        let store = store(events: goals(FreePlanLimit.goals), isPremium: true)
        await store.send(.addButtonTapped)
        #expect(store.state.addEvent != nil)
        #expect(store.state.paywall == nil)
    }

    @Test func billingDisabledHasNoLimits() async {
        let store = store(events: goals(10), billingEnabled: false)
        await store.send(.addButtonTapped)
        #expect(store.state.addEvent != nil)
    }

    @Test func freeUserHitsStepLimit() async {
        let goal = Event(title: "結婚式", date: Date().addingTimeInterval(86400 * 100))
        let steps = (0..<FreePlanLimit.stepsPerParent).map {
            Event(title: "ステップ\($0)", date: Date(), parentId: goal.id)
        }
        let store = store(events: [goal] + steps)
        await store.send(.addStepTapped(parentId: goal.id))
        await store.receive(\.showPaywall) {
            $0.paywall = PaywallFeature.State(reason: .stepLimit)
        }
    }

    @Test func freeUserCannotNestSteps() async {
        let goal = Event(title: "結婚式", date: Date().addingTimeInterval(86400 * 100))
        let step = Event(title: "前撮り", date: Date(), parentId: goal.id)
        let store = store(events: [goal, step])
        await store.send(.addStepTapped(parentId: step.id))
        await store.receive(\.showPaywall) {
            $0.paywall = PaywallFeature.State(reason: .nestedStep)
        }
    }

    @Test func freeUserCanAddFirstStep() async {
        let goal = Event(title: "結婚式", date: Date().addingTimeInterval(86400 * 100))
        let store = store(events: [goal])
        await store.send(.addStepTapped(parentId: goal.id))
        #expect(store.state.addEvent?.event.parentId == goal.id)
    }

    @Test func adsRemainWhileBillingDisabled() {
        var state = CountdownFeature.State()
        state.billingEnabled = false
        #expect(state.hasPremium)
        #expect(!state.removesAds)
        state.billingEnabled = true
        state.isPremium = true
        #expect(state.removesAds)
    }
}
