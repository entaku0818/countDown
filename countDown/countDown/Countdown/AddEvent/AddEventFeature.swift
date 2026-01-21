import SwiftUI
import ComposableArchitecture

// MARK: - Add/Edit Event Feature
@Reducer
struct AddEventFeature {
    enum Mode: Equatable {
        case add
        case edit
    }
    
    // イベント候補のリスト
    static let eventSuggestions: [EventSuggestion] = [
        EventSuggestion(
            category: "イベント",
            suggestions: ["誕生日", "結婚式", "記念日", "卒業式", "入学式"]
        ),
        EventSuggestion(
            category: "祝日・季節",
            suggestions: ["クリスマス", "お正月", "バレンタイン", "ハロウィン", "お花見"]
        ),
        EventSuggestion(
            category: "旅行",
            suggestions: ["旅行", "海外旅行", "国内旅行", "出張", "帰省"]
        ),
        EventSuggestion(
            category: "仕事",
            suggestions: ["締め切り", "プロジェクト完了", "会議", "面接", "発表"]
        )
    ]
    
    @ObservableState
    struct State: Equatable {
        var event: Event
        var mode: Mode = .add
        var showingSuggestions: Bool = false
        var isEventTitleEmpty: Bool = true

        // 通知設定の編集状態を追加
        @Presents var notificationSettings: NotificationSettingsState?

        // 画像選択の状態
        var showingImagePicker: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
        case editNotificationSettingsTapped
        case toggleSuggestions
        case selectSuggestion(String)
        case delegate(Delegate)

        // 画像選択関連のアクション
        case selectImageTapped
        case selectTemplateImage(String?)
        case selectCustomImage(Data)
        case dismissImagePicker

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
                    return .none
                }
                
                // 空白を含むタイトルをトリミング
                var eventToSave = state.event
                eventToSave.title = state.event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                
                return .send(.delegate(.saveEvent(eventToSave)))
                
            case .cancelButtonTapped:
                return .send(.delegate(.dismiss))
                
            case .toggleSuggestions:
                state.showingSuggestions.toggle()
                return .none
                
            case let .selectSuggestion(suggestion):
                state.event.title = suggestion
                state.showingSuggestions = false
                state.isEventTitleEmpty = false
                return .none

            case .selectImageTapped:
                state.showingImagePicker = true
                return .none

            case let .selectTemplateImage(imageName):
                state.event.imageName = imageName
                state.event.customImageData = nil
                state.showingImagePicker = false
                return .none

            case let .selectCustomImage(imageData):
                state.event.customImageData = imageData
                state.event.imageName = nil
                state.showingImagePicker = false
                return .none

            case .dismissImagePicker:
                state.showingImagePicker = false
                return .none

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

// イベント候補のカテゴリと候補リスト
struct EventSuggestion: Equatable {
    let category: String
    let suggestions: [String]
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
