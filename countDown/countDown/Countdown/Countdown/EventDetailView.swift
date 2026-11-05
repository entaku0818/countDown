import SwiftUI
import Combine
import ComposableArchitecture

struct EventDetailView: View {
    @Bindable var store: StoreOf<CountdownFeature>
    let eventId: UUID

    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if let event = store.events.first(where: { $0.id == eventId }) {
            content(event)
        } else {
            // 削除された場合など
            ContentUnavailableView("見つかりません", systemImage: "calendar.badge.exclamationmark")
        }
    }

    @ViewBuilder
    private func content(_ event: Event) -> some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    // 画像表示
                    eventImageView(event)

                    // リアルタイムカウントダウン
                    VStack(spacing: 8) {
                        Text(formattedCountdown(event))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(stringValue: event.color))

                        Text(countdownSuffix(event))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)

                    Text(event.title)
                        .font(.title)
                        .bold()

                    if !event.note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("期待メモ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(event.note)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(stringValue: event.color), lineWidth: 10)
                )
            }
            
            journeySection(event)

            Section("日付") {
                HStack {
                    Text("日付")
                    Spacer()
                    Text(event.date.formatted(date: .long, time: .omitted))
                        .foregroundColor(.secondary)
                }
                if event.repeatType != .none {
                    HStack {
                        Text("繰り返し")
                        Spacer()
                        Text(event.repeatType.rawValue)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("次回")
                        Spacer()
                        Text(event.nextOccurrenceDate.formatted(date: .long, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("表示形式") {
                HStack {
                    Text("表示形式")
                    Spacer()
                    Text(event.displayFormat.style.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("色")
                    Spacer()
                    Circle()
                        .fill(Color(stringValue: event.color))
                        .frame(width: 20, height: 20)
                }
            }
            
            Section {
                ShareButton(
                    title: event.title,
                    date: event.date,
                    description: event.note
                )
            }
        }
        .navigationTitle(event.isGoal ? "ゴール" : "ステップ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.eventTapped(event))
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    /// ゴールまでの道のり（配下のステップ）。ステップの中にさらにステップを作れる
    @ViewBuilder
    private func journeySection(_ event: Event) -> some View {
        let steps = store.events.children(of: event.id)
        Section {
            if let progress = store.events.stepProgress(of: event.id) {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress.ratio)
                        .tint(Color(stringValue: event.color))
                    Text(progress.completed == progress.total
                         ? "すべてのステップを達成！あとは当日を待つだけ"
                         : "\(progress.total)ステップ中 \(progress.completed) 達成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            ForEach(steps) { step in
                stepRow(step)
            }

            Button {
                store.send(.addStepTapped(parentId: event.id))
            } label: {
                Label("ステップを追加", systemImage: "plus.circle")
            }
        } header: {
            Text("\(event.title)までの道のり")
        } footer: {
            if steps.isEmpty {
                Text("「前撮り」「招待状発送」のように、当日までの小さなゴールを登録できます")
            }
        }
    }

    private func stepRow(_ step: Event) -> some View {
        HStack(spacing: 12) {
            Button {
                store.send(.toggleStepCompleted(step.id))
            } label: {
                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(step.isCompleted ? Color(stringValue: step.color) : .secondary)
            }
            .buttonStyle(.plain)

            NavigationLink {
                EventDetailView(store: store, eventId: step.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .strikethrough(step.isCompleted)
                        .foregroundColor(step.isCompleted ? .secondary : .primary)
                    HStack(spacing: 6) {
                        Text(step.displayDate.formatted(date: .abbreviated, time: .omitted))
                        Text(stepCountdownText(step))
                        if let sub = store.events.stepProgress(of: step.id) {
                            Label("\(sub.completed)/\(sub.total)", systemImage: "list.bullet")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                store.send(.deleteEvent(step.id))
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func stepCountdownText(_ step: Event) -> String {
        if step.isCompleted { return "達成" }
        if step.isToday { return "今日" }
        let days = step.daysRemaining
        return days >= 0 ? "あと\(days)日" : "\(-days)日経過"
    }

    /// リアルタイムカウントダウンテキスト
    private func formattedCountdown(_ event: Event) -> String {
        let calendar = Calendar.current
        let targetDate = event.displayDate

        if calendar.isDateInToday(targetDate) {
            return "今日"
        }

        let isPast = now > targetDate

        let components = calendar.dateComponents(
            [.day, .hour, .minute, .second],
            from: isPast ? targetDate : now,
            to: isPast ? now : targetDate
        )

        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0

        return "\(days)日 \(hours)時間 \(minutes)分 \(seconds)秒"
    }

    private func countdownSuffix(_ event: Event) -> String {
        let targetDate = event.displayDate
        let days = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 0
        if Calendar.current.isDateInToday(targetDate) {
            return "今日がその日！"
        } else if now > targetDate {
            return "あの日から"
        } else if days <= 7 {
            return "後、もうすぐ！"
        } else {
            return "後が楽しみ！"
        }
    }

    @ViewBuilder
    private func eventImageView(_ event: Event) -> some View {
        if let imageData = event.customImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let imageName = event.imageName {
            EventImages.image(for: imageName, size: 120)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    let goal = Event(title: "結婚式", date: Date().addingTimeInterval(86400 * 120), color: "pink")
    let store = Store(initialState: CountdownFeature.State(events: [
        goal,
        Event(title: "前撮り", date: Date().addingTimeInterval(86400 * 30), parentId: goal.id, isCompleted: true),
        Event(title: "招待状発送", date: Date().addingTimeInterval(86400 * 60), parentId: goal.id)
    ])) {
        CountdownFeature()
    }
    return NavigationStack {
        EventDetailView(store: store, eventId: goal.id)
    }
}
