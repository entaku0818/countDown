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
                        EventRow(event: event, store: store)
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
                store: store.scope(state: \.$addEvent, action: \.addEvent )
            ) { store in
                NavigationStack {
                    AddEventView(store: store)
                }
            }
            .sheet(
                store: store.scope(state: \.$editEvent, action: \.editEvent )
            ) { store in
                NavigationStack {
                    AddEventView(store: store)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .alert(store: store.scope(state: \.$alert, action: \.alert ))
        }
    }
}

struct EventRow: View {
    var event: Event
    @Bindable var store: StoreOf<CountdownFeature>
    
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
            
            HStack(spacing: 16) {
                ShareButton(
                    title: event.title,
                    date: event.date,
                    description: event.note
                )
                .buttonStyle(PlainButtonStyle())
                
                CountdownDisplay(event: event)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CountdownDisplay: View {
    var event: Event
    
    var body: some View {
        VStack(alignment: .trailing) {
            switch event.displayFormat.style {
            case .days:
                DaysCountdownView(event: event)
            case .progress:
                ProgressCountdownView(event: event)
            case .circle:
                CircleCountdownView(event: event)
            }
        }
    }
}

struct DaysCountdownView: View {
    var event: Event
    
    var body: some View {
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

struct ProgressCountdownView: View {
    var event: Event
    
    var body: some View {
        VStack(alignment: .trailing) {
            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .tint(Color(stringValue: event.color))
            
            Text(countdownText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 100)
    }
    
    private var progressValue: Double {
        if event.isPast {
            return 1.0
        } else if event.isToday {
            return 0.0
        } else {
            return 1.0 - (Double(event.daysRemaining) / 30.0)
        }
    }
    
    private var countdownText: String {
        if event.isToday {
            return "今日"
        } else if event.isPast {
            return "\(abs(event.daysRemaining))日前"
        } else {
            return "あと\(event.daysRemaining)日"
        }
    }
}

struct CircleCountdownView: View {
    var event: Event
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                .frame(width: 50, height: 50)
            
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(Color(stringValue: event.color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
            
            Text(countdownText)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(stringValue: event.color))
        }
    }
    
    private var progressValue: Double {
        if event.isPast {
            return 1.0
        } else if event.isToday {
            return 0.0
        } else {
            return 1.0 - (Double(event.daysRemaining) / 30.0)
        }
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
} 
