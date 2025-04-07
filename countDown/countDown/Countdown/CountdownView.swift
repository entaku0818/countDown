import SwiftUI
import ComposableArchitecture

struct CountdownView: View {
    @Bindable var store: StoreOf<CountdownFeature>
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("並び替え", selection: $store.sortOrder) {
                        Text("日付順").tag(CountdownFeature.State.SortOrder.date)
                        Text("残り日数順").tag(CountdownFeature.State.SortOrder.daysRemaining)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    ForEach(store.filteredEvents) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.send(.eventTapped(event))
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    if let index = store.events.firstIndex(where: { $0.id == event.id }) {
                                        store.send(.deleteEvent(IndexSet(integer: index)))
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .searchable(
                text: $store.searchText,
                prompt: "イベントを検索"
            )
            .navigationTitle("カウントダウン")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(
                store: store.scope(state: \.$addEvent, action: { .addEvent($0) })
            ) { store in
                NavigationStack {
                    AddEventView(store: store)
                }
            }
            .sheet(
                store: store.scope(state: \.$editEvent, action: { .editEvent($0) })
            ) { store in
                NavigationStack {
                    AddEventView(store: store)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

struct EventRow: View {
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
