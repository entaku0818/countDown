import SwiftUI

struct EventRow: View {
    var event: Event
    
    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(stringValue: event.color))
                .frame(width: 10)
                .padding(.trailing, 12)
            
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
} 
