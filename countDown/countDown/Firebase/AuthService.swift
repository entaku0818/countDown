import Foundation
import FirebaseAuth
import ComposableArchitecture
import UIKit

// MARK: - AuthClient Interface
struct AuthClient {
    var signInAnonymously: @Sendable () async throws -> User
    var getCurrentUser: @Sendable () -> User?
    var signOut: @Sendable () throws -> Void
    var getCurrentUserId: @Sendable () -> String
}

// MARK: - User Model
struct User: Equatable, Identifiable {
    var id: String
    var isAnonymous: Bool
}

// MARK: - Live Auth Implementation
extension AuthClient: DependencyKey {
    static var liveValue: Self {
        return Self(
            signInAnonymously: {
                do {
                    let authResult = try await Auth.auth().signInAnonymously()
                    return User(
                        id: authResult.user.uid,
                        isAnonymous: authResult.user.isAnonymous
                    )
                } catch {
                    print("匿名認証エラー: \(error.localizedDescription)")
                    throw AuthError.userNotFound
                }
            },
            getCurrentUser: {
                guard let firebaseUser = Auth.auth().currentUser else {
                    return nil
                }
                return User(
                    id: firebaseUser.uid,
                    isAnonymous: firebaseUser.isAnonymous
                )
            },
            signOut: {
                try Auth.auth().signOut()
            },
            getCurrentUserId: {
                // Firebase Authから現在のユーザーIDを取得
                if let currentUser = Auth.auth().currentUser {
                    return currentUser.uid
                }
                
                // 匿名ユーザーがいない場合は空文字を返す
                return ""
            }
        )
    }
}

// MARK: - Test/Mock Implementation
extension AuthClient {
    static var testValue: Self {
        return Self(
            signInAnonymously: {
                return User(id: "test-user-id", isAnonymous: true)
            },
            getCurrentUser: {
                return User(id: "test-user-id", isAnonymous: true)
            },
            signOut: { },
            getCurrentUserId: {
                return "test-user-id"
            }
        )
    }
}

// MARK: - Dependency Registration
extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

// MARK: - Auth Errors
enum AuthError: Error {
    case userNotFound
    case signInFailed
} 
