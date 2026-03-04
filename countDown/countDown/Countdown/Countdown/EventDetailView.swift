import SwiftUI
import ComposableArchitecture

struct EventDetailView: View {
    let event: Event
    let onEditTapped: (Event) -> Void

    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    // 画像表示
                    eventImageView

                    // リアルタイムカウントダウン
                    VStack(spacing: 8) {
                        Text(formattedCountdown)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(stringValue: event.color))

                        Text(countdownSuffix)
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
        .navigationTitle("イベント詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onEditTapped(event)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    /// リアルタイムカウントダウンテキスト
    private var formattedCountdown: String {
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

    private var countdownSuffix: String {
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
    private var eventImageView: some View {
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
    NavigationStack {
        EventDetailView(
            event: Event(
                title: "サンプルイベント",
                date: Date(),
                color: "blue", note: "これはサンプルのイベントです。",
                displayFormat: DisplayFormat(style: .days)
            ),
            onEditTapped: { _ in }
        )
    }
} 
