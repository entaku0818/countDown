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
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case saveEvent(Event)
            case dismiss
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .saveButtonTapped:
                return .send(.delegate(.saveEvent(state.event)))
                
            case .cancelButtonTapped:
                return .send(.delegate(.dismiss))
                
            case .delegate:
                return .none
            }
        }
    }
} 