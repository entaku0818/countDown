import SwiftUI

struct EventRow: View {
    var event: Event
    @State private var now = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景画像
            eventImageView
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()

            // グラデーションオーバーレイ
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)

            // イベント情報
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // カウントダウン表示
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedCountdown)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)

                    // 通知アイコン
                    if event.hasEnabledNotifications {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                            Text(event.notificationTimingText)
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(12)
        }
        .background(Color(stringValue: event.color))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    @ViewBuilder
    private var eventImageView: some View {
        if let imageData = event.customImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let imageName = event.imageName,
                  let uiImage = UIImage(named: "event_\(imageName)") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            // 画像がない場合は色のみ
            Color(stringValue: event.color)
        }
    }

    /// リアルタイム計算用のカウントダウンテキスト
    private var formattedCountdown: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(event.date) {
            return "今日"
        }

        let isPast = now > event.date
        let mode = event.displayFormat.timeDisplayMode

        // 各コンポーネントを計算
        let components = calendar.dateComponents(
            [.day, .hour, .minute, .second],
            from: isPast ? event.date : now,
            to: isPast ? now : event.date
        )

        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0

        let suffix = isPast ? "経過" : "後"

        switch mode {
        case .daysOnly:
            return "\(days)日\(suffix)"
        case .daysAndHours:
            return "\(days)日 \(hours)時間\(suffix)"
        case .daysHoursMinutes:
            return "\(days)日 \(hours)時間 \(minutes)分\(suffix)"
        case .full:
            return "\(days)日 \(hours)時間 \(minutes)分 \(seconds)秒\(suffix)"
        }
    }
}
