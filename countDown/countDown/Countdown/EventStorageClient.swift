import Foundation
import ComposableArchitecture
import WidgetKit

// MARK: - Event Storage Client
struct EventStorageClient {
    var loadEvents: @Sendable () async -> [Event]
    var saveEvent: @Sendable (Event) async -> Void
    var updateEvent: @Sendable (Event) async -> Void
    var deleteEvent: @Sendable (UUID) async -> Void
}

// MARK: - Live Implementation
extension EventStorageClient: DependencyKey {
    static var liveValue: EventStorageClient = {
        let saveKey = "SavedEvents"

        // UserDefaultsからイベントを読み込む関数
        @Sendable
        func loadEventsFromDefaults() -> [Event] {
            guard let data = UserDefaults.standard.data(forKey: saveKey),
                  let events = try? JSONDecoder().decode([Event].self, from: data) else {
                return []
            }
            return events
        }

        // UserDefaultsにイベントを保存する関数
        @Sendable
        func saveEventsToDefaults(_ events: [Event]) {
            if let encoded = try? JSONEncoder().encode(events) {
                UserDefaults.standard.set(encoded, forKey: saveKey)
            }

            // ウィジェット用にも保存
            SharedDataManager.saveEventsForWidget(events)
        }

        return EventStorageClient(
            loadEvents: {
                let events = loadEventsFromDefaults()
                print("ローカルから\(events.count)件のイベントを読み込みました")

                // ウィジェット用にも同期
                SharedDataManager.saveEventsForWidget(events)

                return events
            },

            saveEvent: { event in
                var events = loadEventsFromDefaults()
                events.append(event)
                saveEventsToDefaults(events)
                print("イベントを保存しました: \(event.title)")
            },

            updateEvent: { event in
                var events = loadEventsFromDefaults()
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = event
                    saveEventsToDefaults(events)
                    print("イベントを更新しました: \(event.title)")
                }
            },

            deleteEvent: { id in
                var events = loadEventsFromDefaults()
                events.removeAll(where: { $0.id == id })
                saveEventsToDefaults(events)
                print("イベントを削除しました: \(id)")
            }
        )
    }()
}

// MARK: - Test Implementation
extension EventStorageClient {
    static var testValue: EventStorageClient {
        return EventStorageClient(
            loadEvents: { [] },
            saveEvent: { _ in },
            updateEvent: { _ in },
            deleteEvent: { _ in }
        )
    }
}

// MARK: - Dependency Registration
extension DependencyValues {
    var eventStorage: EventStorageClient {
        get { self[EventStorageClient.self] }
        set { self[EventStorageClient.self] = newValue }
    }
}
