import Foundation
import FirebaseFirestore
import ComposableArchitecture
import UIKit

// MARK: - Firestore Client
struct FirestoreClient {
    var saveUserToken: @Sendable (String, String) async throws -> Void
    var getUserTokens: @Sendable () async throws -> [UserToken]
    var saveEvent: @Sendable (Event, String, [String]) async throws -> Void
    var getSharedEvents: @Sendable () async throws -> [Event]
}

// MARK: - Models
struct UserToken: Identifiable, Codable, Equatable {
    var id: String // デバイスID
    var token: String // FCMトークン
    var userId: String // ユーザーID (匿名認証も可)
    var createdAt: Date
    var updatedAt: Date
}

extension FirestoreClient: DependencyKey {
    static var liveValue: FirestoreClient = {
        let db = Firestore.firestore()
        

        return FirestoreClient(
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
            },
            
            saveEvent: { event, createdBy, sharedWith in
                let eventRef = db.collection("events").document(event.id.uuidString)
                
                // イベントの基本情報を保存
                let eventData: [String: Any] = [
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
                    ]
                ]
                
                // 共有情報を保存
                let sharingData: [String: Any] = [
                    "eventId": event.id.uuidString,
                    "createdBy": createdBy,
                    "sharedWith": sharedWith,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                try await eventRef.setData(eventData, merge: true)
                
                // 共有情報を別のコレクションに保存
                let sharingRef = db.collection("event_shares").document(event.id.uuidString)
                try await sharingRef.setData(sharingData, merge: true)
                
                print("Saved event to Firestore: \(event.id)")
            },
            
            getSharedEvents: {
                let userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                
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
                var allEvents: [Event] = []
                
                // 10件ずつ取得
                for chunk in stride(from: 0, to: eventIds.count, by: 10) {
                    let end = min(chunk + 10, eventIds.count)
                    let idChunk = Array(eventIds[chunk..<end])
                    
                    let eventsQuery = db.collection("events").whereField("id", in: idChunk)
                    let eventsSnapshot = try await eventsQuery.getDocuments()
                    
                    let events = eventsSnapshot.documents.compactMap { document -> Event? in
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
                    
                    allEvents.append(contentsOf: events)
                }
                
                print("Retrieved \(allEvents.count) shared events from Firestore")
                return allEvents
            }
        )
    }()
}

extension DependencyValues {
    var firestoreClient: FirestoreClient {
        get { self[FirestoreClient.self] }
        set { self[FirestoreClient.self] = newValue }
    }
} 
