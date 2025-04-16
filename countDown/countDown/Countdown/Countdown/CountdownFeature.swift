import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct CountdownFeature {
    @ObservableState
    struct State: Equatable {
        var events: [Event] = []
        var sharedEvents: [Event] = []
        var sortOrder: SortOrder = .date
        var searchText: String = ""
        var filteredEvents: [Event] = []
        var user: User? = nil
        var isSigningIn: Bool = false
        @Presents var addEvent: AddEventFeature.State?
        @Presents var editEvent: AddEventFeature.State?
        @Presents var alert: AlertState<Action.Alert>?
        
        static let freeVersionEventLimit = 3
        
        enum SortOrder: Equatable {
            case date
            case daysRemaining
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case anonymousSignInRequested
        case signInResponse(TaskResult<User>)
        case eventsLoaded([Event])
        case sharedEventsLoaded([Event])
        case addButtonTapped
        case deleteEvent(IndexSet)
        case eventTapped(Event)
        case shareEvent(Event)
        case scheduleNotification(Event)
        case syncEvents
        case showAlert(Alert)
        case addEvent(PresentationAction<AddEventFeature.Action>)
        case editEvent(PresentationAction<AddEventFeature.Action>)
        case updateFilteredEvents
        case alert(PresentationAction<Alert>)
        
        enum Alert: Equatable {
            case eventLimitReached
            case notificationScheduled
            case eventShared
            case error(String)
            case authError(String)
        }
    }
    
    @Dependency(\.eventStorage) var eventStorage
    @Dependency(\.notificationService) var notificationService
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .send(.updateFilteredEvents)
                
            case .updateFilteredEvents:
                state.filteredEvents = sortedAndFilteredEvents(
                    state.events,
                    sortOrder: state.sortOrder,
                    searchText: state.searchText
                )
                return .none
                
            case .onAppear:
                // 既存のユーザーがいるか確認
                if let currentUser = authClient.getCurrentUser() {
                    state.user = currentUser
                    return .run { send in
                        // ローカルとFirestoreのイベントを取得
                        let events = await eventStorage.loadEvents()
                        await send(.eventsLoaded(events))
                        
                        // 共有されたイベントを取得
                        let sharedEvents = await eventStorage.getSharedEvents()
                        await send(.sharedEventsLoaded(sharedEvents))
                    }
                } else {
                    // ユーザーがいなければ匿名サインインを要求
                    return .send(.anonymousSignInRequested)
                }
                
            case .anonymousSignInRequested:
                state.isSigningIn = true
                return .run { send in
                    await send(.signInResponse(
                        TaskResult { try await authClient.signInAnonymously() }
                    ))
                }
                
            case let .signInResponse(.success(user)):
                state.user = user
                state.isSigningIn = false
                return .run { send in
                    // ローカルとFirestoreのイベントを取得
                    let events = await eventStorage.loadEvents()
                    await send(.eventsLoaded(events))
                    
                    // 共有されたイベントを取得
                    let sharedEvents = await eventStorage.getSharedEvents()
                    await send(.sharedEventsLoaded(sharedEvents))
                }
                
            case let .signInResponse(.failure(error)):
                state.isSigningIn = false
                state.user = nil
                return .send(.showAlert(.authError("認証エラーが発生しました: \(error.localizedDescription)")))
                
            case let .eventsLoaded(events):
                state.events = events
                return .send(.updateFilteredEvents)
                
            case let .sharedEventsLoaded(events):
                state.sharedEvents = events
                return .none
                
            case .syncEvents:
                return .run { _ in
                    await eventStorage.synchronizeEvents()
                }
                
            case .addButtonTapped:
                if state.events.count >= State.freeVersionEventLimit {
                    state.alert = AlertState {
                        TextState("イベント数の制限に達しました")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                        ButtonState {
                            TextState("プレミアム版にアップグレード")
                        }
                    } message: {
                        TextState("無料版では最大3つのイベントしか登録できません。プレミアム版にアップグレードすると、無制限にイベントを登録できます。")
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
                        await eventStorage.deleteEvent(event.id)
                    }
                    await send(.updateFilteredEvents)
                }
                
            case let .eventTapped(event):
                state.editEvent = AddEventFeature.State(event: event, mode: .edit)
                return .none
                
            case let .shareEvent(event):
                // ユーザーIDを匿名ユーザーのIDに変更
                let userId = state.user?.id ?? UUID().uuidString
                // 仮のユーザーリスト（実際にはグループ機能から選択）
                let sharedWith = ["user1", "user2"]
                let sharingInfo = SharingInfo(createdBy: userId, sharedWith: sharedWith)
                
                return .run { send in
                    await eventStorage.updateEvent(event, sharingInfo)
                    await send(.showAlert(.eventShared))
                }
                
            case let .scheduleNotification(event):
                return .run { send in
                    // イベント前日の通知を設定
                    let calendar = Calendar.current
                    if let notificationDate = calendar.date(byAdding: .day, value: -1, to: event.date) {
                        let title = "明日はイベントの日です"
                        let body = "\(event.title)まであと1日です"
                        
                        // ユーザーIDを取得
                        let userId = authClient.getCurrentUserId()
                        if !userId.isEmpty {
                            await notificationService.scheduleLocalNotification(title, body, notificationDate, userId)
                            await send(.showAlert(.notificationScheduled))
                        } else {
                            await send(.showAlert(.error("通知の設定に失敗しました：ユーザーIDが取得できません")))
                        }
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
                        TextState("イベント前日に通知が届きます")
                    }
                case .eventShared:
                    state.alert = AlertState {
                        TextState("イベントを共有しました")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("選択したユーザーとイベントが共有されました")
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
                case let .authError(message):
                    state.alert = AlertState {
                        TextState("認証エラー")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                        ButtonState {
                            TextState("再試行")
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
                        ButtonState {
                            TextState("プレミアム版にアップグレード")
                        }
                    } message: {
                        TextState("無料版では最大3つのイベントしか登録できません。プレミアム版にアップグレードすると、無制限にイベントを登録できます。")
                    }
                }
                return .none
                
            case let .addEvent(.presented(.delegate(.saveEvent(event)))):
                state.events.append(event)
                state.addEvent = nil
                return .run { send in
                    // イベントを保存（共有情報なし）
                    await eventStorage.saveEvent(event, nil)
                    await send(.updateFilteredEvents)
                    await send(.scheduleNotification(event))
                }
                
            case let .editEvent(.presented(.delegate(.saveEvent(event)))):
                if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                    state.events[index] = event
                }
                state.editEvent = nil
                return .run { send in
                    // 既存の共有情報は維持したまま更新
                    await eventStorage.updateEvent(event, nil)
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
    
    private func sortedAndFilteredEvents(_ events: [Event], sortOrder: State.SortOrder, searchText: String) -> [Event] {
        var filteredEvents = events
        
        // 検索フィルタリング
        if !searchText.isEmpty {
            filteredEvents = filteredEvents.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.note.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 並び替え
        return filteredEvents.sorted { event1, event2 in
            switch sortOrder {
            case .date:
                return event1.date < event2.date
            case .daysRemaining:
                return event1.daysRemaining < event2.daysRemaining
            }
        }
    }
} 
