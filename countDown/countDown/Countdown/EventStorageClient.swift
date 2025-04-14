import Foundation
import FirebaseFirestore
import ComposableArchitecture
import UIKit

// MARK: - Event Storage Client
struct EventStorageClient {
    // イベント関連
    var loadEvents: @Sendable () async -> [Event]
    var saveEvent: @Sendable (Event, SharingInfo?) async -> Void
    var updateEvent: @Sendable (Event, SharingInfo?) async -> Void
    var deleteEvent: @Sendable (UUID) async -> Void
    var getSharedEvents: @Sendable () async -> [Event]
    var synchronizeEvents: @Sendable () async -> Void
    
    // プッシュ通知トークン関連
    var saveUserToken: @Sendable (String, String) async throws -> Void
    var getUserTokens: @Sendable () async throws -> [UserToken]
}

// MARK: - Models
struct UserToken: Identifiable, Codable, Equatable {
    var id: String // デバイスID
    var token: String // FCMトークン
    var userId: String // ユーザーID (匿名認証も可)
    var createdAt: Date
    var updatedAt: Date
}

struct SharingInfo: Equatable {
    var createdBy: String
    var sharedWith: [String]
    
    init(createdBy: String, sharedWith: [String] = []) {
        self.createdBy = createdBy
        self.sharedWith = sharedWith
    }
}

extension EventStorageClient: DependencyKey {
    static var liveValue: EventStorageClient = {
        let db = Firestore.firestore()
        let saveKey = "SavedEvents"
        
        // Firestoreの設定
        let settings = db.settings
        db.settings = settings
        
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
        @Sendable func saveEventsToDefaults(_ events: [Event]) {
            if let encoded = try? JSONEncoder().encode(events) {
                UserDefaults.standard.set(encoded, forKey: saveKey)
            }
        }
        
        // Firestoreからイベントをパースする関数
        func parseEventFromFirestore(document: QueryDocumentSnapshot) -> Event? {
            let data = document.data()
            
            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let title = data["title"] as? String,
                  let date = (data["date"] as? Timestamp)?.dateValue(),
                  let color = data["color"] as? String,
                  let note = data["note"] as? String,
                  let displayFormatData = data["displayFormat"] as? [String: Any],
                  let showDays = displayFormatData["showDays"] as? Bool,
                  let showHours = displayFormatData["showHours"] as? Bool,
                  let showMinutes = displayFormatData["showMinutes"] as? Bool,
                  let showSeconds = displayFormatData["showSeconds"] as? Bool,
                  let styleString = displayFormatData["style"] as? String else {
                print("Failed to parse event: \(document.documentID)")
                return nil
            }
            
            // スタイルのパース
            let style = DisplayFormat.CountdownStyle(rawValue: styleString) ?? .days
            
            // DisplayFormatの作成
            let displayFormat = DisplayFormat(
                showDays: showDays,
                showHours: showHours,
                showMinutes: showMinutes,
                showSeconds: showSeconds,
                style: style
            )
            
            // イベントオブジェクトの作成
            return Event(
                id: id,
                title: title,
                date: date,
                color: color,
                note: note,
                displayFormat: displayFormat
            )
        }
        
        // イベントをFirestoreのドキュメントに変換する関数
        func eventToFirestoreData(event: Event) -> [String: Any] {
            return [
                "id": event.id.uuidString,
                "title": event.title,
                "date": event.date,
                "color": event.color,
                "note": event.note,
                "displayFormat": [
                    "showDays": event.displayFormat.showDays,
                    "showHours": event.displayFormat.showHours,
                    "showMinutes": event.displayFormat.showMinutes,
                    "showSeconds": event.displayFormat.showSeconds,
                    "style": event.displayFormat.style.rawValue
                ],
                "updatedAt": FieldValue.serverTimestamp()
            ]
        }
        
        // 共有情報をFirestoreのドキュメントに変換する関数
        func sharingInfoToFirestoreData(eventId: UUID, info: SharingInfo) -> [String: Any] {
            return [
                "eventId": eventId.uuidString,
                "createdBy": info.createdBy,
                "sharedWith": info.sharedWith,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
        }
        
        return EventStorageClient(
            loadEvents: {
                var allEvents: [Event] = []
                
                // まずUserDefaultsから取得
                let localEvents = loadEventsFromDefaults()
                
                do {
                    // Firestoreからイベントを取得
                    let userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                    let eventsQuery = db.collection("events")
                    let eventsSnapshot = try await eventsQuery.getDocuments()
                    
                    let events = eventsSnapshot.documents.compactMap { parseEventFromFirestore(document: $0) }
                    
                    // ローカルイベントとFirestoreから取得したイベントをマージ
                    // 基本的にFirestoreの方が新しいと仮定
                    var mergedEvents: [Event] = []
                    var firestoreEventIds = Set<UUID>()
                    
                    // Firestoreから取得したイベントを先に追加
                    for event in events {
                        mergedEvents.append(event)
                        firestoreEventIds.insert(event.id)
                    }
                    
                    // ローカルにあってFirestoreにないイベントを追加
                    for event in localEvents {
                        if !firestoreEventIds.contains(event.id) {
                            mergedEvents.append(event)
                        }
                    }
                    
                    allEvents = mergedEvents
                    
                    // マージ結果をUserDefaultsに保存
                    saveEventsToDefaults(mergedEvents)
                    
                    print("Retrieved \(allEvents.count) events (merged from Firestore and local)")
                } catch {
                    print("Failed to fetch events from Firestore, using local events: \(error.localizedDescription)")
                    allEvents = localEvents
                }
                
                return allEvents
            },
            
            saveEvent: { event, sharingInfo in
                // まずUserDefaultsに保存する
                var events = loadEventsFromDefaults()
                events.append(event)
                saveEventsToDefaults(events)
                
                // Firestoreに保存を試みる
                do {
                    let eventRef = db.collection("events").document(event.id.uuidString)
                    let eventData = eventToFirestoreData(event: event)
                    
                    try await eventRef.setData(eventData, merge: true)
                    
                    // 共有情報があれば保存
                    if let info = sharingInfo, !info.sharedWith.isEmpty {
                        let sharingRef = db.collection("event_shares").document(event.id.uuidString)
                        let sharingData = sharingInfoToFirestoreData(eventId: event.id, info: info)
                        try await sharingRef.setData(sharingData, merge: true)
                    }
                    
                    print("Saved event to Firestore: \(event.id)")
                } catch {
                    print("Failed to save event to Firestore, but saved to UserDefaults: \(error.localizedDescription)")
                }
            },
            
            updateEvent: { event, sharingInfo in
                // まずUserDefaultsに保存する
                var events = loadEventsFromDefaults()
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = event
                    saveEventsToDefaults(events)
                }
                
                // Firestoreに保存を試みる
                do {
                    let eventRef = db.collection("events").document(event.id.uuidString)
                    let eventData = eventToFirestoreData(event: event)
                    
                    try await eventRef.setData(eventData, merge: true)
                    
                    // 共有情報があれば更新
                    if let info = sharingInfo {
                        let sharingRef = db.collection("event_shares").document(event.id.uuidString)
                        let sharingData = sharingInfoToFirestoreData(eventId: event.id, info: info)
                        try await sharingRef.setData(sharingData, merge: true)
                    }
                    
                    print("Updated event in Firestore: \(event.id)")
                } catch {
                    print("Failed to update event in Firestore, but updated in UserDefaults: \(error.localizedDescription)")
                }
            },
            
            deleteEvent: { id in
                // まずUserDefaultsから削除する
                var events = loadEventsFromDefaults()
                events.removeAll(where: { $0.id == id })
                saveEventsToDefaults(events)
                
                // Firestoreから削除を試みる
                do {
                    let eventRef = db.collection("events").document(id.uuidString)
                    try await eventRef.delete()
                    
                    // 共有情報も削除
                    let sharingRef = db.collection("event_shares").document(id.uuidString)
                    try await sharingRef.delete()
                    
                    print("Deleted event from Firestore: \(id)")
                } catch {
                    print("Failed to delete event from Firestore, but deleted from UserDefaults: \(error.localizedDescription)")
                }
            },
            
            getSharedEvents: {
                let userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                var allEvents: [Event] = []
                
                do {
                    // 共有情報コレクションからユーザーに共有されているイベントIDを取得
                    let sharingQuery = db.collection("event_shares").whereField("sharedWith", arrayContains: userId)
                    let sharingSnapshot = try await sharingQuery.getDocuments()
                    print("Retrieved \(sharingSnapshot.documents.count) shared event references")
                    
                    // イベントIDの配列を作成
                    let eventIds = sharingSnapshot.documents.compactMap { doc -> String? in
                        let data = doc.data()
                        return data["eventId"] as? String
                    }
                    
                    // 空の配列ならすぐに返す
                    if eventIds.isEmpty {
                        return []
                    }
                    
                    // バッチで取得（FirestoreはIN句で最大10件まで）
                    // 10件ずつ取得
                    for chunk in stride(from: 0, to: eventIds.count, by: 10) {
                        let end = min(chunk + 10, eventIds.count)
                        let idChunk = Array(eventIds[chunk..<end])
                        
                        let eventsQuery = db.collection("events").whereField("id", in: idChunk)
                        let eventsSnapshot = try await eventsQuery.getDocuments()
                        
                        let events = eventsSnapshot.documents.compactMap { parseEventFromFirestore(document: $0) }
                        
                        allEvents.append(contentsOf: events)
                    }
                    
                    print("Retrieved \(allEvents.count) shared events from Firestore")
                } catch {
                    print("Failed to fetch shared events from Firestore: \(error.localizedDescription)")
                }
                
                return allEvents
            },
            
            synchronizeEvents: {
                do {
                    // ローカルイベントを取得
                    let localEvents = loadEventsFromDefaults()
                    
                    // Firestoreに全てのローカルイベントを同期
                    for event in localEvents {
                        let eventRef = db.collection("events").document(event.id.uuidString)
                        let eventData = eventToFirestoreData(event: event)
                        try await eventRef.setData(eventData, merge: true)
                    }
                    
                    print("Synchronized \(localEvents.count) events to Firestore")
                } catch {
                    print("Failed to synchronize events with Firestore: \(error.localizedDescription)")
                }
            },
            
            saveUserToken: { deviceId, token in
                let userTokenRef = db.collection("user_tokens").document(deviceId)
                let userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                
                let tokenData: [String: Any] = [
                    "id": deviceId,
                    "token": token,
                    "userId": userId,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                try await userTokenRef.setData(tokenData, merge: true)
                print("Saved user token to Firestore: \(deviceId)")
            },
            
            getUserTokens: {
                let snapshot = try await db.collection("user_tokens").getDocuments()
                print("Retrieved \(snapshot.documents.count) user tokens from Firestore")
                
                return snapshot.documents.compactMap { document -> UserToken? in
                    let data = document.data()
                    
                    guard let id = data["id"] as? String,
                          let token = data["token"] as? String,
                          let userId = data["userId"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
                        print("Failed to parse user token: \(document.documentID)")
                        return nil
                    }
                    
                    return UserToken(
                        id: id,
                        token: token,
                        userId: userId,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                }
            }
        )
    }()
}

extension DependencyValues {
    var eventStorage: EventStorageClient {
        get { self[EventStorageClient.self] }
        set { self[EventStorageClient.self] = newValue }
    }
} 
