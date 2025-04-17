import SwiftUI
import ComposableArchitecture

struct NotificationSettingsView: View {
    let event: Event
    @Binding var notificationSettings: [NotificationSettings]
    @State private var selectedTimingIndex = 0
    @State private var isEnabled = true
    @State private var showCustomTimingSheet = false
    @State private var customDays = 1
    
    // 通知タイミングの選択肢
    private let timingOptions: [NotificationTiming] = [
        .dayBefore,
        .weekBefore,
        .monthBefore,
        .sameDay,
        .custom(days: 3),
        .none
    ]
    
    // タイミングの表示名
    private var timingNames: [String] {
        return timingOptions.map { $0.description }
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("通知設定")) {
                    // 通知の有効/無効切り替え
                    Toggle("通知を有効にする", isOn: $isEnabled)
                        .onChange(of: isEnabled) { newValue in
                            updatePrimaryNotificationSetting()
                        }
                    
                    // 通知が有効な場合のみタイミング選択を表示
                    if isEnabled {
                        // 通知タイミングの選択
                        Picker("通知タイミング", selection: $selectedTimingIndex) {
                            ForEach(0..<timingNames.count, id: \.self) { index in
                                Text(timingNames[index])
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedTimingIndex) { newValue in
                            updatePrimaryNotificationSetting()
                            
                            // カスタム設定が選択された場合
                            if case .custom = timingOptions[selectedTimingIndex] {
                                showCustomTimingSheet = true
                            }
                        }
                        
                        // カスタムタイミングが選択されている場合、詳細を表示
                        if case .custom(let days) = getCurrentTiming() {
                            HStack {
                                Text("カスタム通知")
                                Spacer()
                                Text("\(days)日前")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                customDays = days
                                showCustomTimingSheet = true
                            }
                        }
                    }
                }
                
                // 通知の概要情報
                Section(header: Text("通知概要")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("イベント: \(event.title)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("日付: \(formattedDate(event.date))")
                            .foregroundColor(.secondary)
                        
                        if isEnabled && getCurrentTiming() != .none {
                            if let date = notificationDate() {
                                Text("通知予定: \(formattedDate(date))")
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("通知: 無効")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("通知設定")
        .onAppear {
            // 初期値の設定
            setupInitialValues()
        }
        .sheet(isPresented: $showCustomTimingSheet) {
            // カスタム通知設定シート
            CustomTimingSheet(
                days: $customDays,
                onSave: { days in
                    updateCustomTiming(days: days)
                }
            )
        }
    }
    
    // 初期値のセットアップ
    private func setupInitialValues() {
        guard let primarySetting = event.primaryNotificationSetting else {
            return
        }
        
        // 通知の有効/無効状態を設定
        isEnabled = primarySetting.isEnabled
        
        // 現在の通知タイミングに対応するインデックスを選択
        if let index = timingOptions.firstIndex(where: { isSameTiming($0, primarySetting.timing) }) {
            selectedTimingIndex = index
        }
        
        // カスタムタイミングの場合、日数を設定
        if case .custom(let days) = primarySetting.timing {
            customDays = days
        }
    }
    
    // 主要な通知設定を更新
    private func updatePrimaryNotificationSetting() {
        // 既存の設定がない場合は新規作成
        if notificationSettings.isEmpty {
            let newSetting = NotificationSettings(
                isEnabled: isEnabled,
                timing: getCurrentTiming(),
                eventId: event.id
            )
            notificationSettings = [newSetting]
        } else {
            // 既存の設定を更新
            var updatedSettings = notificationSettings
            updatedSettings[0].isEnabled = isEnabled
            updatedSettings[0].timing = getCurrentTiming()
            notificationSettings = updatedSettings
        }
    }
    
    // カスタムタイミングを更新
    private func updateCustomTiming(days: Int) {
        let customTiming: NotificationTiming = .custom(days: days)
        
        // タイミングの配列内のカスタムタイミングのインデックスを探す
        if let index = timingOptions.firstIndex(where: { 
            if case .custom = $0 { return true } else { return false }
        }) {
            selectedTimingIndex = index
        }
        
        // 通知設定を更新
        if notificationSettings.isEmpty {
            let newSetting = NotificationSettings(
                isEnabled: isEnabled,
                timing: customTiming,
                eventId: event.id
            )
            notificationSettings = [newSetting]
        } else {
            var updatedSettings = notificationSettings
            updatedSettings[0].timing = customTiming
            notificationSettings = updatedSettings
        }
    }
    
    // 現在選択されているタイミングを取得
    private func getCurrentTiming() -> NotificationTiming {
        let timing = timingOptions[selectedTimingIndex]
        if case .custom = timing {
            return .custom(days: customDays)
        }
        return timing
    }
    
    // 通知予定日時を計算
    private func notificationDate() -> Date? {
        return getCurrentTiming().notificationDate(for: event.date)
    }
    
    // 日付のフォーマット
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // タイミングが同じかどうか（カスタムの場合は種類のみで比較）
    private func isSameTiming(_ a: NotificationTiming, _ b: NotificationTiming) -> Bool {
        switch (a, b) {
        case (.none, .none), (.sameDay, .sameDay), (.dayBefore, .dayBefore),
             (.weekBefore, .weekBefore), (.monthBefore, .monthBefore):
            return true
        case (.custom, .custom):
            return true
        default:
            return false
        }
    }
}

// カスタム通知タイミング設定用のシート
struct CustomTimingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var days: Int
    let onSave: (Int) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("カスタム通知日数")) {
                    Stepper(value: $days, in: 1...365) {
                        HStack {
                            Text("イベントの")
                            Spacer()
                            Text("\(days)日前")
                                .bold()
                        }
                    }
                    
                    Text("イベントの\(days)日前に通知が送信されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("カスタム通知設定")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("保存") {
                    onSave(days)
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    // プレビュー用のダミーデータ
    let event = Event(
        title: "誕生日",
        date: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
        note: "パーティの準備をする"
    )
    
    return NavigationView {
        NotificationSettingsView(
            event: event,
            notificationSettings: .constant([
                NotificationSettings(
                    isEnabled: true,
                    timing: .dayBefore,
                    eventId: event.id
                )
            ])
        )
    }
} 