import SwiftUI
import ComposableArchitecture

struct CountdownListView: View {
    @Bindable var store: StoreOf<CountdownFeature>
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.events) { event in
                    Button {
                        store.send(.eventTapped(event))
                    } label: {
                        EventRowView(event: event)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    store.send(.deleteEvent(indexSet))
                }
            }
            .navigationTitle("カウントダウン")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(item: $store.scope(state: \.addEvent, action: \.addEvent)) { store in
                NavigationStack {
                    AddEventView(store: store)
                        .navigationTitle("イベント追加")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") {
                                    self.store.send(.addEvent(.dismiss))
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("保存") {
                                    store.send(.saveButtonTapped)
                                }
                                .disabled(store.event.title.isEmpty)
                            }
                        }
                }
            }
            .sheet(item: $store.scope(state: \.editEvent, action: \.editEvent)) { store in
                NavigationStack {
                    AddEventView(store: store)
                        .navigationTitle("イベント編集")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") {
                                    self.store.send(.editEvent(.dismiss))
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("保存") {
                                    store.send(.saveButtonTapped)
                                }
                                .disabled(store.event.title.isEmpty)
                            }
                        }
                }
            }
        }
    }
}

struct EventRowView: View {
    var event: Event
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.headline)
                Text(event.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(countdownText)
                    .font(.title)
                    .bold()
                    .foregroundColor(countdownColor)
                
                Text(countdownLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var countdownText: String {
        if event.isToday {
            return "今日"
        } else if event.isPast {
            return "\(abs(event.daysRemaining))"
        } else {
            return "\(event.daysRemaining)"
        }
    }
    
    private var countdownLabel: String {
        if event.isToday {
            return "当日です！"
        } else if event.isPast {
            return "日前"
        } else {
            return "日後"
        }
    }
    
    private var countdownColor: Color {
        if event.isToday {
            return .green
        } else if event.isPast {
            return .secondary
        } else {
            return Color(stringValue: event.color)
        }
    }
} 