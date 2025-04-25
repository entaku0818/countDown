import SwiftUI
import ComposableArchitecture

// MARK: - Add/Edit Event Feature
@Reducer
struct AddEventFeature {
    enum Mode: Equatable {
        case add
        case edit
    }
    
    @ObservableState
    struct State: Equatable {
        var event: Event
        var mode: Mode = .add
        var isEventTitleEmpty: Bool = false
        
        // 通知設定の編集状態を追加
        @Presents var notificationSettings: NotificationSettingsState?
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
        case editNotificationSettingsTapped
        case delegate(Delegate)
        
        // 通知設定関連のアクションを追加
        case notificationSettings(PresentationAction<NotificationSettingsReducer.Action>)

        enum Delegate: Equatable {
            case saveEvent(Event)
            case dismiss
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            case .binding:
                return .none
                
            case .saveButtonTapped:
                // タイトルが空または空白文字のみの場合は保存しない
                if state.event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.isEventTitleEmpty = true
                    return .none
                }
                
                // 空白を含むタイトルをトリミング
                var eventToSave = state.event
                eventToSave.title = state.event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                
                return .send(.delegate(.saveEvent(eventToSave)))
                
            case .cancelButtonTapped:
                return .send(.delegate(.dismiss))
                
            case .editNotificationSettingsTapped:
                // 通知設定画面を表示
                state.notificationSettings = NotificationSettingsState(
                    event: state.event,
                    notificationSettings: state.event.notificationSettings
                )
                return .none
                
            case let .notificationSettings(.presented(.delegate(.saveNotificationSettings(settings)))):
                // 通知設定を更新
                var updatedEvent = state.event
                updatedEvent.notificationSettings = settings
                state.event = updatedEvent
                state.notificationSettings = nil
                return .none
                
            case .notificationSettings(.presented(.delegate(.dismiss))):
                // 通知設定画面を閉じる
                state.notificationSettings = nil
                return .none
                
            case .notificationSettings(.dismiss):
                // 通知設定画面を閉じる
                state.notificationSettings = nil
                return .none
                
            case .notificationSettings:
                return .none
                
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$notificationSettings, action: /Action.notificationSettings) {
            NotificationSettingsReducer()
        }
    }
}

// MARK: - Notification Settings Feature
@Reducer
struct NotificationSettingsReducer {
    @ObservableState
    struct State: Equatable {
        var event: Event
        var notificationSettings: [NotificationSettings]
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case saveNotificationSettings([NotificationSettings])
            case dismiss
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .saveButtonTapped:
                return .send(.delegate(.saveNotificationSettings(state.notificationSettings)))
                
            case .cancelButtonTapped:
                return .send(.delegate(.dismiss))
                
            case .delegate:
                return .none
            }
        }
    }
}

typealias NotificationSettingsState = NotificationSettingsReducer.State 
