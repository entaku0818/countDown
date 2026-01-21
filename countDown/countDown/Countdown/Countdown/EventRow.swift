import SwiftUI

struct EventRow: View {
    var event: Event

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
                    Text(countdownText)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Text(countdownLabel)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
        }
        .background(Color(stringValue: event.color))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private var countdownText: String {
        if event.isToday {
            return "今日"
        } else if event.isPast {
            return "\(event.daysPassed)日"
        } else {
            return "\(event.daysRemaining)日"
        }
    }

    private var countdownLabel: String {
        if event.isToday {
            return ""
        } else if event.isPast {
            return "経過"
        } else {
            return "後"
        }
    }
}
