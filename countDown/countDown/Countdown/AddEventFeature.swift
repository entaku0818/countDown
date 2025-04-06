import SwiftUI
import ComposableArchitecture

// MARK: - Add/Edit Event Feature
@Reducer
struct AddEventFeature {
    enum Mode: Equatable {
        case add
        case edit
    }
    
    @ObservableState
    struct State: Equatable {
        var event: Event
        var mode: Mode = .add
    }
    
    enum Action: Equatable {
        case titleChanged(String)
        case dateChanged(Date)
        case colorChanged(String)
        case noteChanged(String)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case saveEvent(Event)
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .titleChanged(title):
                state.event.title = title
                return .none
                
            case let .dateChanged(date):
                state.event.date = date
                return .none
                
            case let .colorChanged(color):
                state.event.color = color
                return .none
                
            case let .noteChanged(note):
                state.event.note = note
                return .none
                
            case .saveButtonTapped:
                return .send(.delegate(.saveEvent(state.event)))
                
            case .cancelButtonTapped:
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View for Add/Edit Event
struct AddEventView: View {
    @Bindable var store: StoreOf<AddEventFeature>
    
    var body: some View {
        Form {
            Section(header: Text("イベント情報")) {
                TextField("イベント名", text: $store.event.title.sending(\.titleChanged))
                
                DatePicker(
                    "日付",
                    selection: $store.event.date.sending(\.dateChanged),
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
                                store.send(.colorChanged(eventColor.rawValue))
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("メモ")) {
                if #available(iOS 16.0, *) {
                    TextEditor(text: Binding(
                        get: { store.event.note ?? "" },
                        set: { store.send(.noteChanged($0)) }
                    ))
                    .frame(minHeight: 100)
                } else {
                    TextEditor(text: Binding(
                        get: { store.event.note ?? "" },
                        set: { store.send(.noteChanged($0)) }
                    ))
                    .frame(height: 100)
                }
            }
        }
    }
}

struct ColorButton: View {
    var color: Color
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
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