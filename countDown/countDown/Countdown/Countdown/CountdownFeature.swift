import Foundation
import SwiftUI
import ComposableArchitecture
import UIKit

@Reducer
struct CountdownFeature {
    @ObservableState
    struct State: Equatable {
        var events: [Event] = []
        var filteredEvents: [Event] = []
        var shouldShowLaunchAd: Bool = false
        var shouldShowEventAddedAd: Bool = false
        @Presents var addEvent: AddEventFeature.State?
        @Presents var editEvent: AddEventFeature.State?
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var paywall: PaywallFeature.State?
        var isPremium: Bool = false
        /// 課金が有効化されているか（RevenueCat の APIキー投入済み）
        var billingEnabled: Bool = RevenueCatConfig.isConfigured

        /// 無料枠の制限を受けないか（課金未設定の間は全員 true）
        var hasPremium: Bool { !billingEnabled || isPremium }
        /// 広告を消すか（課金未設定の間は従来どおり広告あり）
        var removesAds: Bool { billingEnabled && isPremium }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case eventsLoaded([Event])
        case addButtonTapped
        case deleteEvent(UUID)
        case eventTapped(Event)
        case addStepTapped(parentId: UUID)
        case toggleStepCompleted(UUID)
        case scheduleNotification(Event)
        case showAlert(Alert)
        case addEvent(PresentationAction<AddEventFeature.Action>)
        case editEvent(PresentationAction<AddEventFeature.Action>)
        case updateFilteredEvents
        case alert(PresentationAction<Alert>)
        case startPremium
        case premiumChanged(Bool)
        case showPaywall(PaywallFeature.Reason)
        case paywall(PresentationAction<PaywallFeature.Action>)

        enum Alert: Equatable {
            case eventLimitReached
            case notificationScheduled
            case error(String)
        }
    }

    @Dependency(\.eventStorage) var eventStorage
    @Dependency(\.alarmService) var alarmService
    @Dependency(\.purchaseClient) var purchaseClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .send(.updateFilteredEvents)

            case .updateFilteredEvents:
                state.filteredEvents = sortedEvents(state.events)
                print("CountdownFeature: updateFilteredEvents - events: \(state.events.count), filtered: \(state.filteredEvents.count)")
                return .none

            case .onAppear:
                return .run { send in
                    let events = await eventStorage.loadEvents()
                    await send(.eventsLoaded(events))
                }

            case let .eventsLoaded(events):
                print("CountdownFeature: eventsLoaded - \(events.count)件")
                for event in events {
                    print("  - \(event.title): \(event.date)")
                }
                state.events = events
                return .send(.updateFilteredEvents)

            case .addButtonTapped:
                if !state.hasPremium && state.events.goals.count >= FreePlanLimit.goals {
                    return .send(.showPaywall(.goalLimit))
                }
                state.addEvent = AddEventFeature.State(event: Event(title: "", date: Date()))
                return .none

            case let .deleteEvent(id):
                // ゴールを消したら配下のステップもすべて消す
                let idsToDelete = Set([id] + state.events.descendantIds(of: id))
                state.events.removeAll { idsToDelete.contains($0.id) }
                return .run { send in
                    for eventId in idsToDelete {
                        // 通知もキャンセル
                        _ = await alarmService.cancelEventNotifications(eventId)
                        await eventStorage.deleteEvent(eventId)
                    }
                    await send(.updateFilteredEvents)
                }

            case let .addStepTapped(parentId):
                if !state.hasPremium {
                    if state.events.depth(of: parentId) + 1 > FreePlanLimit.stepDepth {
                        return .send(.showPaywall(.nestedStep))
                    }
                    if state.events.children(of: parentId).count >= FreePlanLimit.stepsPerParent {
                        return .send(.showPaywall(.stepLimit))
                    }
                }
                let parent = state.events.first { $0.id == parentId }
                state.addEvent = AddEventFeature.State(
                    event: Event(
                        title: "",
                        date: Date(),
                        color: parent?.color ?? "blue",
                        parentId: parentId
                    )
                )
                return .none

            case let .toggleStepCompleted(id):
                guard let index = state.events.firstIndex(where: { $0.id == id }) else { return .none }
                state.events[index].isCompleted.toggle()
                let event = state.events[index]
                return .run { send in
                    await eventStorage.updateEvent(event)
                    await send(.updateFilteredEvents)
                }

            case let .eventTapped(event):
                state.editEvent = AddEventFeature.State(event: event, mode: .edit)
                return .none

            case let .scheduleNotification(event):
                return .run { send in
                    let success = await alarmService.scheduleEventNotifications(event)
                    if success {
                        await send(.showAlert(.notificationScheduled))
                    } else {
                        await send(.showAlert(.error("通知のスケジュールに失敗しました")))
                    }
                }

            case let .showAlert(alertType):
                switch alertType {
                case .notificationScheduled:
                    state.alert = AlertState {
                        TextState("通知がスケジュールされました")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("イベント前に通知が届きます")
                    }
                case let .error(message):
                    state.alert = AlertState {
                        TextState("エラーが発生しました")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState(message)
                    }
                case .eventLimitReached:
                    state.alert = AlertState {
                        TextState("イベント数の制限に達しました")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("無料版では最大3つのイベントしか登録できません。後日、プレミアム版にアップグレードできるようになります。")
                    }
                }
                return .none

            case let .addEvent(.presented(.delegate(.saveEvent(event)))):
                state.events.append(event)
                state.addEvent = nil
                return .run { send in
                    await eventStorage.saveEvent(event)

                    // 通知設定が有効な場合、通知をスケジュール
                    if event.hasEnabledNotifications {
                        await send(.scheduleNotification(event))
                    }

                    await send(.updateFilteredEvents)
                }

            case let .editEvent(.presented(.delegate(.saveEvent(event)))):
                if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                    state.events[index] = event
                }
                state.editEvent = nil
                return .run { send in
                    await eventStorage.updateEvent(event)

                    // 通知を更新
                    if event.hasEnabledNotifications {
                        let success = await alarmService.updateEventNotifications(event)
                        if !success {
                            await send(.showAlert(.error("通知の更新に失敗しました")))
                        }
                    } else {
                        // 通知が無効になっていれば通知をキャンセル
                        _ = await alarmService.cancelEventNotifications(event.id)
                    }

                    await send(.updateFilteredEvents)
                }

            case .addEvent(.presented(.delegate(.dismiss))):
                state.addEvent = nil
                return .none

            case .editEvent(.presented(.delegate(.dismiss))):
                state.editEvent = nil
                return .none

            case .addEvent(.dismiss):
                state.addEvent = nil
                return .none

            case .editEvent(.dismiss):
                state.editEvent = nil
                return .none

            case .addEvent, .editEvent:
                return .none

            case .startPremium:
                return .run { send in
                    purchaseClient.configure()
                    for await isPremium in purchaseClient.premiumStream() {
                        await send(.premiumChanged(isPremium))
                    }
                }

            case let .premiumChanged(isPremium):
                state.isPremium = isPremium
                PremiumStatus.update(isPremium)
                // ウィジェットの写真・完了チェックの解放状態を反映
                SharedDataManager.saveEventsForWidget(state.events)
                return .none

            case let .showPaywall(reason):
                state.paywall = PaywallFeature.State(reason: reason)
                return .none

            case .paywall(.presented(.delegate(.premiumActivated))):
                state.paywall = nil
                return .send(.premiumChanged(true))

            case .paywall(.presented(.delegate(.close))):
                state.paywall = nil
                return .none

            case .paywall:
                return .none

            case .alert(.dismiss):
                state.alert = nil
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$addEvent, action: \.addEvent) {
            AddEventFeature()
        }
        .ifLet(\.$editEvent, action: \.editEvent) {
            AddEventFeature()
        }
        .ifLet(\.$paywall, action: \.paywall) {
            PaywallFeature()
        }
    }

    private func sortedEvents(_ events: [Event]) -> [Event] {
        return events.sorted { event1, event2 in
            return event1.displayDate < event2.displayDate
        }
    }
}
