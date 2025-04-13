import SwiftUI

struct EventRow: View {
    var event: Event
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.headline)
                Text(event.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                ShareButton(
                    title: event.title,
                    date: event.date,
                    description: event.note
                )
                
                CountdownDisplay(event: event)
            }
        }
        .padding(.vertical, 8)
    }
} 