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