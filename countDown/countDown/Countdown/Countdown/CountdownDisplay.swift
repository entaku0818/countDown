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
        VStack(alignment: .trailing, spacing: 4) {
            if event.isToday {
                Text("今日")
                    .font(.title)
                    .bold()
                    .foregroundColor(.green)

                Text("当日です！")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // フォーマットに応じた表示
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(formattedCountdown)
                        .font(.title)
                        .bold()
                        .foregroundColor(countdownColor)

                    Text(countdownSuffix)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// フォーマットに応じたカウントダウンテキスト
    private var formattedCountdown: String {
        let mode = event.displayFormat.timeDisplayMode

        if event.isPast {
            // 過去のイベント
            switch mode {
            case .daysOnly:
                return "\(event.daysPassed)日"
            case .daysAndHours:
                return "\(event.daysPassed)日 \(abs(event.hoursRemaining))時間"
            case .daysHoursMinutes:
                return "\(event.daysPassed)日 \(abs(event.hoursRemaining))時間 \(abs(event.minutesRemaining))分"
            case .full:
                return "\(event.daysPassed)日 \(abs(event.hoursRemaining))時間 \(abs(event.minutesRemaining))分 \(abs(event.secondsRemaining))秒"
            }
        } else {
            // 未来のイベント
            switch mode {
            case .daysOnly:
                return "\(event.daysRemaining)日"
            case .daysAndHours:
                return "\(event.daysRemaining)日 \(event.hoursRemaining)時間"
            case .daysHoursMinutes:
                return "\(event.daysRemaining)日 \(event.hoursRemaining)時間 \(event.minutesRemaining)分"
            case .full:
                return "\(event.daysRemaining)日 \(event.hoursRemaining)時間 \(event.minutesRemaining)分 \(event.secondsRemaining)秒"
            }
        }
    }

    private var countdownSuffix: String {
        if event.isPast {
            return "経過"
        } else {
            return "後"
        }
    }

    private var countdownColor: Color {
        if event.isPast {
            return .secondary
        } else {
            return Color(stringValue: event.color)
        }
    }
}
