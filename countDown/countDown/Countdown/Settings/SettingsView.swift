import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let user: User?
    
    @Dependency(\.notificationService) var notificationService
    
    // デバッグモードフラグ（実際の環境では false にする）
    #if DEBUG
    @State private var isDebugMode = true
    #else
    @State private var isDebugMode = false
    #endif
    
    @State private var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    @State private var tokenStatus: TokenStatus?
    @State private var showCopiedMessage = false
    
    var body: some View {
        List {
            Section("通知設定") {
                HStack {
                    Text("通知")
                    Spacer()
                    Text(notificationStatusText)
                        .foregroundColor(notificationStatusColor)
                }
                
                Button("通知設定を開く") {
                    notificationService.openNotificationSettings()
                }
            }
            
            Section("一般設定") {
                NavigationLink(destination: Text("利用規約画面をここに実装")) {
                    Text("利用規約")
                }
                
                NavigationLink(destination: Text("プライバシーポリシー画面をここに実装")) {
                    Text("プライバシーポリシー")
                }
            }
            
            #if DEBUG
            Section {
                Toggle("デバッグモード", isOn: $isDebugMode)
            }
            #endif
            
            // デバッグモードの場合のみユーザー情報を表示
            if isDebugMode, let user = user {
                Section("デバッグ情報") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ユーザー情報")
                            .font(.headline)
                        
                        HStack {
                            Text("ユーザータイプ:")
                            Spacer()
                            Text(user.isAnonymous ? "匿名ユーザー" : "認証済みユーザー")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("ユーザーID:")
                            Spacer()
                            Text(user.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // トークン情報
                    if let tokenStatus = tokenStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("通知トークン情報")
                                .font(.headline)
                            
                            Group {
                                Text("登録状態: \(tokenStatus.isRegistered ? "登録済み" : "未登録")")
                                    .foregroundColor(tokenStatus.isRegistered ? .green : .red)
                                
                                if let fcmToken = tokenStatus.fcmToken {
                                    Text("FCMトークン:")
                                    VStack(alignment: .leading) {
                                        Text(fcmToken)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            .onTapGesture {
                                                UIPasteboard.general.string = fcmToken
                                                showCopiedMessage = true
                                                
                                                // コンソールにもトークンを表示
                                                print("======================= FCM TOKEN (COPIED) =======================")
                                                print("\(fcmToken)")
                                                print("================================================================")
                                                
                                                // 3秒後に通知を消す
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                    showCopiedMessage = false
                                                }
                                            }
                                        
                                        Button("コピー") {
                                            UIPasteboard.general.string = fcmToken
                                            showCopiedMessage = true
                                            
                                            // コンソールにもトークンを表示
                                            print("======================= FCM TOKEN (COPIED) =======================")
                                            print("\(fcmToken)")
                                            print("================================================================")
                                            
                                            // 3秒後に通知を消す
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                showCopiedMessage = false
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                } else {
                                    Text("FCMトークン: 未取得")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button("通知テスト") {
                        scheduleTestNotification()
                    }
                    
                    if showCopiedMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("FCMトークンをコピーしました")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showCopiedMessage)
                    }
                }
            }
            
            Section {
                Button(action: {
                    // アプリ情報ダイアログを表示
                }) {
                    Text("アプリについて")
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    // アプリの評価画面を表示
                }) {
                    Text("アプリを評価する")
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("設定")
        .onAppear {
            loadNotificationStatus()
        }
    }
    
    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized:
            return "許可済み"
        case .denied:
            return "拒否"
        case .notDetermined:
            return "未設定"
        case .provisional:
            return "暫定的に許可"
        case .ephemeral:
            return "一時的に許可"
        case .unknown:
            return "不明"
        }
    }
    
    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined, .unknown:
            return .orange
        }
    }
    
    private func loadNotificationStatus() {
        Task {
            // 通知ステータスを取得
            notificationStatus = await notificationService.getNotificationStatus()
            
            // トークンステータスを取得（ユーザーIDを引数に渡す）
            if let userId = user?.id {
                tokenStatus = notificationService.getTokenStatus(userId)
                
                // トークンが取得できたらコンソールに表示
                if let fcmToken = tokenStatus?.fcmToken {
                    print("======================= FCM TOKEN (AVAILABLE) =======================")
                    print("\(fcmToken)")
                    print("====================================================================")
                }
            }
        }
    }
    
    private func scheduleTestNotification() {
        Task {
            let now = Date()
            let testDate = now.addingTimeInterval(10) // 10秒後
            
            // ユーザーIDを取得（userがnilの場合は空文字列を使用）
            let userId = user?.id ?? ""
            if !userId.isEmpty {
                await notificationService.scheduleLocalNotification("テスト通知", "これはテスト通知です", testDate, userId)
            } else {
                print("テスト通知の送信に失敗: ユーザーIDが空です")
            }
        }
    }
} 
