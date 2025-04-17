import SwiftUI
import ComposableArchitecture

struct AddEventView: View {
    @Bindable var store: StoreOf<AddEventFeature>
    
    var body: some View {
        Form {
            Section(header: Text("イベント情報")) {
                TextField("イベント名", text: $store.event.title)
                
                DatePicker(
                    "日付",
                    selection: $store.event.date,
                    displayedComponents: .date
                )
            }
            
            Section(header: Text("通知")) {
                NavigationLink {
                    NotificationSettingsView(
                        event: store.event,
                        notificationSettings: Binding(
                            get: { store.notificationSettings?.notificationSettings ?? store.event.notificationSettings },
                            set: { newValue in
                                var updatedEvent = store.event
                                updatedEvent.notificationSettings = newValue
                                store.event = updatedEvent
                            }
                        )
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") {
                                store.send(.notificationSettings(.presented(.saveButtonTapped)))
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(store.event.hasEnabledNotifications ? .blue : .gray)
                        
                        Text("通知設定")
                        
                        Spacer()
                        
                        Text(store.event.notificationTimingText)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("カラー")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(EventColor.allCases, id: \.rawValue) { eventColor in
                            ColorButton(
                                color: eventColor.colorValue,
                                isSelected: store.event.color == eventColor.rawValue
                            ) {
                                store.event.color = eventColor.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("表示形式")) {
                Picker("スタイル", selection: $store.event.displayFormat.style) {
                    ForEach(DisplayFormat.CountdownStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                Toggle("日数表示", isOn: $store.event.displayFormat.showDays)
                Toggle("時間表示", isOn: $store.event.displayFormat.showHours)
                Toggle("分表示", isOn: $store.event.displayFormat.showMinutes)
                Toggle("秒表示", isOn: $store.event.displayFormat.showSeconds)
            }
            
            Section(header: Text("メモ")) {
                if #available(iOS 16.0, *) {
                    TextEditor(text: $store.event.note)
                        .frame(minHeight: 100)
                } else {
                    TextEditor(text: $store.event.note)
                        .frame(height: 100)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    store.send(.cancelButtonTapped)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    store.send(.saveButtonTapped)
                }
            }
        }
        .sheet(store: store.scope(state: \.$notificationSettings, action: { .notificationSettings($0) })) { store in
            NavigationView {
                NotificationSettingsSheetView(store: store)
            }
        }
    }
}

struct NotificationSettingsSheetView: View {
    @Bindable var store: StoreOf<NotificationSettingsReducer>
    
    var body: some View {
        NotificationSettingsView(
            event: store.event,
            notificationSettings: $store.notificationSettings
        )
        .navigationTitle("通知設定")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    store.send(.cancelButtonTapped)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    store.send(.saveButtonTapped)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddEventView(
            store: Store(
                initialState: AddEventFeature.State(
                    event: Event(
                        title: "誕生日パーティー",
                        date: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
                        color: "blue",
                        note: "友達を招待する"
                    )
                )
            ) {
                AddEventFeature()
            }
        )
        .navigationTitle("イベント追加")
        .navigationBarTitleDisplayMode(.inline)
    }
} 