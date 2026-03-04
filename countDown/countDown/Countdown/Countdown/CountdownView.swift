import SwiftUI
import ComposableArchitecture

struct CountdownView: View {
    @Bindable var store: StoreOf<CountdownFeature>

    @ViewBuilder
    private func eventRow(_ event: Event) -> some View {
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

    private var upcomingEvents: [Event] {
        store.filteredEvents.filter { !$0.isPast || $0.repeatType != .none }
    }

    private var memoryEvents: [Event] {
        store.filteredEvents.filter { $0.isPast && $0.repeatType == .none }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                        // カウントダウン中のイベント
                        Section {
                            ForEach(upcomingEvents) { event in
                                eventRow(event)
                            }
                        }

                        // 思い出セクション
                        if !memoryEvents.isEmpty {
                            Section {
                                ForEach(memoryEvents) { event in
                                    eventRow(event)
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("思い出")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
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
