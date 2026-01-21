import SwiftUI

struct EventRow: View {
    var event: Event

    var body: some View {
        HStack(spacing: 12) {
            // 画像表示
            eventImageView
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                Text(event.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                CountdownDisplay(event: event)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var eventImageView: some View {
        if let imageData = event.customImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let imageName = event.imageName {
            EventImages.image(for: imageName, size: 50)
        } else {
            // 画像がない場合は色付きの四角
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(stringValue: event.color))
                .frame(width: 50, height: 50)
        }
    }
} 
