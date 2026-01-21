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
            // 過去のイベント（詳細表示用の日数を使用）
            let days = abs(event.daysRemainingDetailed)
            let hours = abs(event.hoursRemaining)
            let minutes = abs(event.minutesRemaining)
            let seconds = abs(event.secondsRemaining)

            switch mode {
            case .daysOnly:
                return "\(event.daysPassed)日"
            case .daysAndHours:
                return "\(days)日 \(hours)時間"
            case .daysHoursMinutes:
                return "\(days)日 \(hours)時間 \(minutes)分"
            case .full:
                return "\(days)日 \(hours)時間 \(minutes)分 \(seconds)秒"
            }
        } else {
            // 未来のイベント（詳細表示用の日数を使用）
            let days = event.daysRemainingDetailed
            let hours = event.hoursRemaining
            let minutes = event.minutesRemaining
            let seconds = event.secondsRemaining

            switch mode {
            case .daysOnly:
                return "\(event.daysRemaining)日"
            case .daysAndHours:
                return "\(days)日 \(hours)時間"
            case .daysHoursMinutes:
                return "\(days)日 \(hours)時間 \(minutes)分"
            case .full:
                return "\(days)日 \(hours)時間 \(minutes)分 \(seconds)秒"
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
