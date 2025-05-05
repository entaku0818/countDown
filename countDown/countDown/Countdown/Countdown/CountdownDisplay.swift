import SwiftUI

struct CountdownDisplay: View {
    var event: Event
    
    var body: some View {
        DaysCountdownView(event: event)
    }
}

struct DaysCountdownView: View {
    var event: Event
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(countdownText)
                    .font(.title)
                    .bold()
                    .foregroundColor(countdownColor)
                
                Text(countdownLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if event.isWithinSevenDays && !event.isPast && !event.isToday {
                Text("\(event.hoursRemaining % 24)時間 \(event.minutesRemaining % 60)分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var countdownText: String {
        if event.isToday {
            return "今日"
        } else if event.isPast {
            return "\(abs(event.daysRemaining))"
        } else {
            return "\(event.daysRemaining)"
        }
    }
    
    private var countdownLabel: String {
        if event.isToday {
            return "当日です！"
        } else if event.isPast {
            return "日前"
        } else {
            return "日後"
        }
    }
    
    private var countdownColor: Color {
        if event.isToday {
            return .green
        } else if event.isPast {
            return .secondary
        } else {
            return Color(stringValue: event.color)
        }
    }
} 