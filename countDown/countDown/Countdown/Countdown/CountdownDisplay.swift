import SwiftUI

struct CountdownDisplay: View {
    var event: Event
    
    var body: some View {
        VStack(alignment: .trailing) {
            switch event.displayFormat.style {
            case .days:
                DaysCountdownView(event: event)
            case .progress:
                ProgressCountdownView(event: event)
            case .circle:
                CircleCountdownView(event: event)
            }
        }
    }
}

struct DaysCountdownView: View {
    var event: Event
    
    var body: some View {
        VStack(alignment: .trailing) {
            Text(countdownText)
                .font(.title)
                .bold()
                .foregroundColor(countdownColor)
            
            Text(countdownLabel)
                .font(.caption)
                .foregroundColor(.secondary)
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

struct ProgressCountdownView: View {
    var event: Event
    
    var body: some View {
        VStack(alignment: .trailing) {
            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .tint(Color(stringValue: event.color))
            
            Text(countdownText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 100)
    }
    
    private var progressValue: Double {
        if event.isPast {
            return 1.0
        } else if event.isToday {
            return 0.0
        } else {
            return 1.0 - (Double(event.daysRemaining) / 30.0)
        }
    }
    
    private var countdownText: String {
        if event.isToday {
            return "今日"
        } else if event.isPast {
            return "\(abs(event.daysRemaining))日前"
        } else {
            return "あと\(event.daysRemaining)日"
        }
    }
}

struct CircleCountdownView: View {
    var event: Event
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                .frame(width: 50, height: 50)
            
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(Color(stringValue: event.color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
            
            Text(countdownText)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(stringValue: event.color))
        }
    }
    
    private var progressValue: Double {
        if event.isPast {
            return 1.0
        } else if event.isToday {
            return 0.0
        } else {
            return 1.0 - (Double(event.daysRemaining) / 30.0)
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
} 