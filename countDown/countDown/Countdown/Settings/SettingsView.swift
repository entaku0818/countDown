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
                                
                                if let apnsToken = tokenStatus.apnsToken {
                                    Text("APNSトークン:")
                                    Text(apnsToken)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("APNSトークン: 未取得")
                                        .foregroundColor(.red)
                                }
                                
                                if let fcmToken = tokenStatus.fcmToken {
                                    Text("FCMトークン:")
                                    Text(fcmToken)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
            
            // トークンステータスを取得
            tokenStatus = notificationService.getTokenStatus()
        }
    }
    
    private func scheduleTestNotification() {
        Task {
            let now = Date()
            let testDate = now.addingTimeInterval(10) // 10秒後
            await notificationService.scheduleLocalNotification("テスト通知", "これはテスト通知です", testDate)
        }
    }
} 