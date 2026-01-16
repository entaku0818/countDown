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

        static let freeVersionEventLimit = 3
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case eventsLoaded([Event])
        case addButtonTapped
        case deleteEvent(IndexSet)
        case eventTapped(Event)
        case scheduleNotification(Event)
        case showAlert(Alert)
        case addEvent(PresentationAction<AddEventFeature.Action>)
        case editEvent(PresentationAction<AddEventFeature.Action>)
        case updateFilteredEvents
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case eventLimitReached
            case notificationScheduled
            case error(String)
        }
    }

    @Dependency(\.eventStorage) var eventStorage
    @Dependency(\.alarmService) var alarmService

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .send(.updateFilteredEvents)

            case .updateFilteredEvents:
                state.filteredEvents = sortedEvents(state.events)
                return .none

            case .onAppear:
                return .run { send in
                    let events = await eventStorage.loadEvents()
                    await send(.eventsLoaded(events))
                }

            case let .eventsLoaded(events):
                state.events = events
                return .send(.updateFilteredEvents)

            case .addButtonTapped:
                if state.events.count >= State.freeVersionEventLimit {
                    state.alert = AlertState {
                        TextState("イベント数の制限に達しました")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("無料版では最大3つのイベントしか登録できません。後日、プレミアム版にアップグレードできるようになります。")
                    }
                    return .none
                }
                state.addEvent = AddEventFeature.State(event: Event(title: "", date: Date()))
                return .none

            case let .deleteEvent(indexSet):
                let eventsToDelete = indexSet.map { state.events[$0] }
                state.events.remove(atOffsets: indexSet)
                return .run { send in
                    for event in eventsToDelete {
                        // 通知もキャンセル
                        _ = await alarmService.cancelEventNotifications(event.id)
                        await eventStorage.deleteEvent(event.id)
                    }
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
    }

    private func sortedEvents(_ events: [Event]) -> [Event] {
        return events.sorted { event1, event2 in
            return event1.date < event2.date
        }
    }
}
