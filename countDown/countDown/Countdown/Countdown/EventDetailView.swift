import SwiftUI
import ComposableArchitecture

struct EventDetailView: View {
    let event: Event
    let onEditTapped: (Event) -> Void
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    // 画像表示
                    eventImageView

                    CountdownDisplay(event: event)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)

                    Text(event.title)
                        .font(.title)
                        .bold()

                    if !event.note.isEmpty {
                        Text(event.note)
                            .font(.body)
                            .foregroundColor(.secondary)
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
