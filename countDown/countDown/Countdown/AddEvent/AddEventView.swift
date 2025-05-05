import SwiftUI
import ComposableArchitecture

struct AddEventView: View {
    @Bindable var store: StoreOf<AddEventFeature>
    
    var body: some View {
        Form {
            Section(header: Text("イベント情報")) {
                HStack {
                    TextField("イベント名", text: $store.event.title)
                    
                    Button(action: {
                        store.send(.toggleSuggestions)
                    }) {
                        Image(systemName: "text.magnifyingglass")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                if store.showingSuggestions {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("候補")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(AddEventFeature.eventSuggestions, id: \.category) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.category)
                                    .font(.footnote.bold())
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(category.suggestions, id: \.self) { suggestion in
                                            Button(action: {
                                                store.send(.selectSuggestion(suggestion))
                                            }) {
                                                Text(suggestion)
                                                    .font(.subheadline)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 12)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundColor(.primary)
                                                    .cornerRadius(16)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                DatePicker(
                    "日付",
                    selection: $store.event.date,
                    displayedComponents: .date
                )
            }
            
            Section(header: Text("通知")) {
                Button {
                    store.send(.editNotificationSettingsTapped)
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(store.event.hasEnabledNotifications ? .blue : .gray)
                        
                        Text("通知設定")
                        
                        Spacer()
                        
                        Text(store.event.notificationTimingText)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .foregroundColor(.primary)
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
                .disabled(store.event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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