import Foundation
import ComposableArchitecture

// MARK: - Event Client
struct EventClient {
    var loadEvents: @Sendable () async -> [Event]
    var saveEvent: @Sendable (Event) async -> Void
    var updateEvent: @Sendable (Event) async -> Void
    var deleteEvent: @Sendable (UUID) async -> Void
}

extension EventClient: DependencyKey {
    static var liveValue: EventClient = {
        let saveKey = "SavedEvents"
        
        return EventClient(
            loadEvents: {
                guard let data = UserDefaults.standard.data(forKey: saveKey),
                      let events = try? JSONDecoder().decode([Event].self, from: data) else {
                    return []
                }
                return events
            },
            saveEvent: { event in
                var events = await loadEvents()
                events.append(event)
                if let encoded = try? JSONEncoder().encode(events) {
                    UserDefaults.standard.set(encoded, forKey: saveKey)
                }
            },
            updateEvent: { updatedEvent in
                var events = await loadEvents()
                if let index = events.firstIndex(where: { $0.id == updatedEvent.id }) {
                    events[index] = updatedEvent
                    if let encoded = try? JSONEncoder().encode(events) {
                        UserDefaults.standard.set(encoded, forKey: saveKey)
                    }
                }
            },
            deleteEvent: { id in
                var events = await loadEvents()
                events.removeAll(where: { $0.id == id })
                if let encoded = try? JSONEncoder().encode(events) {
                    UserDefaults.standard.set(encoded, forKey: saveKey)
                }
            }
        )
        
        func loadEvents() async -> [Event] {
            guard let data = UserDefaults.standard.data(forKey: saveKey),
                  let events = try? JSONDecoder().decode([Event].self, from: data) else {
                return []
            }
            return events
        }
    }()
}

extension DependencyValues {
    var eventClient: EventClient {
        get { self[EventClient.self] }
        set { self[EventClient.self] = newValue }
    }
} 