import Foundation
import SwiftUI
import ComposableArchitecture

// MARK: - Event Model
struct Event: Equatable, Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var color: String
    var note: String
    var displayFormat: DisplayFormat
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        color: String = "blue",
        note: String = "",
        displayFormat: DisplayFormat = DisplayFormat()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.color = color
        self.note = note
        self.displayFormat = displayFormat
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day ?? 0
    }
    
    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    var isPast: Bool {
        return Date() > date
    }
}

// MARK: - Display Format
struct DisplayFormat: Equatable, Codable {
    var showDays: Bool = true
    var showHours: Bool = false
    var showMinutes: Bool = false
    var showSeconds: Bool = false
    var style: CountdownStyle = .days
    
    enum CountdownStyle: String, CaseIterable, Codable {
        case days = "日数"
        case progress = "進捗バー"
        case circle = "サークル"
    }
}

// MARK: - Color Utilities
enum EventColor: String, CaseIterable, Codable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    
    var colorValue: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}

extension Color {
    init(stringValue: String) {
        switch stringValue {
        case "red": self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green": self = .green
        case "blue": self = .blue
        case "purple": self = .purple
        case "pink": self = .pink
        default: self = .blue
        }
    }
}

// MARK: - Feature Domain
@Reducer
struct CountdownFeature {
    @ObservableState
    struct State: Equatable {
        var events: [Event] = []
        var sortOrder: SortOrder = .date
        var searchText: String = ""
        var filteredEvents: [Event] = []
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
        case eventsLoaded([Event])
        case addButtonTapped
        case deleteEvent(IndexSet)
        case eventTapped(Event)
        case addEvent(PresentationAction<AddEventFeature.Action>)
        case editEvent(PresentationAction<AddEventFeature.Action>)
        case updateFilteredEvents
        case alert(PresentationAction<Alert>)
        
        enum Alert: Equatable {
            case eventLimitReached
        }
    }
    
    @Dependency(\.eventClient) var eventClient
    
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
                return .run { send in
                    let events = await eventClient.loadEvents()
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
                        await eventClient.deleteEvent(event.id)
                    }
                    await send(.updateFilteredEvents)
                }
                
            case let .eventTapped(event):
                state.editEvent = AddEventFeature.State(event: event, mode: .edit)
                return .none
                
            case let .addEvent(.presented(.delegate(.saveEvent(event)))):
                state.events.append(event)
                state.addEvent = nil
                return .run { send in
                    await eventClient.saveEvent(event)
                    await send(.updateFilteredEvents)
                }
                
            case .addEvent(.dismiss):
                state.addEvent = nil
                return .none
                
            case let .editEvent(.presented(.delegate(.saveEvent(event)))):
                if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                    state.events[index] = event
                }
                state.editEvent = nil
                return .run { send in
                    await eventClient.saveEvent(event)
                    await send(.updateFilteredEvents)
                }
                
            case .editEvent(.dismiss):
                state.editEvent = nil
                return .none
                
            case .addEvent, .editEvent:
                return .none
            case .alert(_):
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
