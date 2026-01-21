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
            // メイン表示（日数）
            if event.isToday {
                Text("今日")
                    .font(.title)
                    .bold()
                    .foregroundColor(.green)

                Text("当日です！")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(countdownText)
                        .font(.title)
                        .bold()
                        .foregroundColor(countdownColor)

                    Text(countdownLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 詳細時間表示（設定に基づく）
            if shouldShowDetailedTime {
                Text(detailedTimeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var countdownText: String {
        if event.isPast {
            return "\(event.daysPassed)"
        } else {
            return "\(event.daysRemaining)"
        }
    }

    private var countdownLabel: String {
        if event.isPast {
            return "日経過"
        } else {
            return "日後"
        }
    }

    private var countdownColor: Color {
        if event.isPast {
            return .secondary
        } else {
            return Color(stringValue: event.color)
        }
    }

    /// 詳細時間を表示するかどうか
    private var shouldShowDetailedTime: Bool {
        let format = event.displayFormat
        // 過去のイベントでなく、時間・分・秒のいずれかが有効な場合
        if event.isPast || event.isToday {
            return false
        }
        return format.showHours || format.showMinutes || format.showSeconds
    }

    /// 詳細時間のテキスト
    private var detailedTimeText: String {
        let format = event.displayFormat
        var parts: [String] = []

        if format.showHours {
            parts.append("\(event.hoursRemaining)時間")
        }
        if format.showMinutes {
            parts.append("\(event.minutesRemaining)分")
        }
        if format.showSeconds {
            parts.append("\(event.secondsRemaining)秒")
        }

        return parts.joined(separator: " ")
    }
}
