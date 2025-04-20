import SwiftUI
import ComposableArchitecture

struct CountdownView: View {
    @Bindable var store: StoreOf<CountdownFeature>
    
    var body: some View {
        NavigationStack {
            ZStack {
                // サインイン中のローディングオーバーレイ
                if store.isSigningIn {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView("認証中...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                        .shadow(radius: 10)
                }
                
                VStack(spacing: 0) {
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
                                NavigationLink {
                                    EventDetailView(event: event)
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
                    }
                    .searchable(
                        text: $store.searchText,
                        prompt: "イベントを検索"
                    )
                    
                    // バナー広告の表示
                    AdmobBannerView()
                        .frame(height: 50)
                }
                .navigationTitle("カウントダウン")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink(destination: SettingsView(user: store.user)) {
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
} 
