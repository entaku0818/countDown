import SwiftUI
import ComposableArchitecture

struct CountdownView: View {
    @Bindable var store: StoreOf<CountdownFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(store.filteredEvents) { event in
                        NavigationLink {
                            EventDetailView(
                                event: event,
                                onEditTapped: { event in
                                    store.send(.eventTapped(event))
                                }
                            )
                        } label: {
                            EventRow(event: event)
                        }
                        .swipeActions {
                            Button {
                                store.send(.eventTapped(event))
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }
                            .tint(.blue)

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
                .listStyle(PlainListStyle())

                // バナー広告の表示
                AdmobBannerView()
                    .frame(height: 50)
            }
            .navigationTitle("カウントダウン")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(
                store: store.scope(state: \.$addEvent, action: \.addEvent)
            ) { store in
                NavigationStack {
                    AddEventView(store: store)
                }
            }
            .sheet(
                store: store.scope(state: \.$editEvent, action: \.editEvent)
            ) { store in
                NavigationStack {
                    AddEventView(store: store)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .alert(store: store.scope(state: \.$alert, action: \.alert))
        }
    }
}
