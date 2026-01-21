import SwiftUI
import ComposableArchitecture

struct CountdownView: View {
    @Bindable var store: StoreOf<CountdownFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
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
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button {
                                    store.send(.eventTapped(event))
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }

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
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

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
                print("CountdownView: onAppear called")
                store.send(.onAppear)
            }
            .onChange(of: store.filteredEvents.count) { oldValue, newValue in
                print("CountdownView: filteredEvents changed from \(oldValue) to \(newValue)")
            }
            .alert(store: store.scope(state: \.$alert, action: \.alert))
        }
    }
}
