import Foundation
import SwiftUI
import ComposableArchitecture

// MARK: - Event Model
struct Event: Equatable, Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var color: String
    var note: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        color: String = "blue",
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.color = color
        self.note = note
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
        var events: IdentifiedArrayOf<Event> = []
        var sortOrder: SortOrder = .date
        var searchText: String = ""
        @Presents var addEvent: AddEventFeature.State?
        @Presents var editEvent: AddEventFeature.State?
        
        enum SortOrder: Equatable {
            case date
            case daysRemaining
        }
    }
    
    enum Action: Equatable {
        case onAppear
        case eventsLoaded([Event])
        case addButtonTapped
        case deleteEvent(IndexSet)
        case eventTapped(Event)
        case addEvent(PresentationAction<AddEventFeature.Action>)
        case editEvent(PresentationAction<AddEventFeature.Action>)
        case setSortOrder(State.SortOrder)
        case searchTextChanged(String)
    }
    
    @Dependency(\.eventClient) var eventClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let events = await eventClient.loadEvents()
                    await send(.eventsLoaded(events))
                }
                
            case let .eventsLoaded(events):
                state.events = IdentifiedArrayOf(uniqueElements: events)
                return .none
                
            case .addButtonTapped:
                state.addEvent = AddEventFeature.State(event: Event(title: "", date: Date()))
                return .none
                
            case let .deleteEvent(indexSet):
                let eventsToDelete = indexSet.map { state.events[$0] }
                state.events.remove(atOffsets: indexSet)
                return .run { _ in
                    for event in eventsToDelete {
                        await eventClient.deleteEvent(event.id)
                    }
                }
                
            case let .eventTapped(event):
                state.editEvent = AddEventFeature.State(event: event, mode: .edit)
                return .none
                
            case let .addEvent(.presented(.delegate(.saveEvent(event)))):
                state.events.append(event)
                state.addEvent = nil
                return .run { _ in
                    await eventClient.saveEvent(event)
                }
                
            case .addEvent(.dismiss):
                state.addEvent = nil
                return .none
                
            case let .editEvent(.presented(.delegate(.saveEvent(event)))):
                if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                    state.events[index] = event
                }
                state.editEvent = nil
                return .run { _ in
                    await eventClient.updateEvent(event)
                }
                
            case .editEvent(.dismiss):
                state.editEvent = nil
                return .none
                
            case let .setSortOrder(order):
                state.sortOrder = order
                return .none
                
            case let .searchTextChanged(text):
                state.searchText = text
                return .none
                
            case .addEvent, .editEvent:
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
    
    func sortedAndFilteredEvents(_ events: IdentifiedArrayOf<Event>, sortOrder: State.SortOrder, searchText: String) -> [Event] {
        var filteredEvents = Array(events)
        
        // 検索フィルタリング
        if !searchText.isEmpty {
            filteredEvents = filteredEvents.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                (event.note?.localizedCaseInsensitiveContains(searchText) ?? false)
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
