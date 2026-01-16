import SwiftUI
import ComposableArchitecture
import SafariServices

struct SettingsView: View {
    @Dependency(\.alarmService) var alarmService

    @State private var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    @State private var showTermsWebView = false
    @State private var showPrivacyWebView = false

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
                    alarmService.openNotificationSettings()
                }
            }

            Section("一般設定") {
                Button("利用規約") {
                    showTermsWebView = true
                }

                Button("プライバシーポリシー") {
                    showPrivacyWebView = true
                }
            }

            #if DEBUG
            Section("デバッグ") {
                Button("テスト通知（10秒後）") {
                    scheduleTestNotification()
                }
            }
            #endif
        }
        .navigationTitle("設定")
        .onAppear {
            loadNotificationStatus()
        }
        .sheet(isPresented: $showTermsWebView) {
            SafariView(url: URL(string: "https://countdown-336cf.web.app/terms_of_service.html")!)
        }
        .sheet(isPresented: $showPrivacyWebView) {
            SafariView(url: URL(string: "https://countdown-336cf.web.app/privacy_policy.html")!)
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
            notificationStatus = await alarmService.getNotificationStatus()
        }
    }

    private func scheduleTestNotification() {
        Task {
            let testEvent = Event(
                title: "テスト通知",
                date: Date().addingTimeInterval(10),
                notificationSettings: [
                    NotificationSettings(
                        isEnabled: true,
                        timing: .sameDay,
                        eventId: UUID()
                    )
                ]
            )
            _ = await alarmService.scheduleEventNotifications(testEvent)
        }
    }
}

// SafariView を実装
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}
