//
//  countDownWidgetsLiveActivity.swift
//  countDownWidgets
//
//  Created by 遠藤拓弥 on 2026/01/17.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes
struct CountdownActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 残り日数
        var daysRemaining: Int
        /// 残り時間
        var hoursRemaining: Int
        /// 残り分
        var minutesRemaining: Int
        /// イベントが過去かどうか
        var isPast: Bool
        /// 経過日数（カウントアップ用）
        var daysPassed: Int
    }

    /// イベントID
    var eventId: String
    /// イベント名
    var eventTitle: String
    /// イベントの色
    var eventColor: String
    /// 目標日時
    var targetDate: Date
}

// MARK: - Live Activity Widget
struct countDownWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            // ロック画面/バナー UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展開時のUI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.eventTitle)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownBadge(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if context.state.isPast {
                            Text("\(context.state.daysPassed)日経過")
                                .font(.title2)
                                .bold()
                        } else if context.state.daysRemaining == 0 {
                            Text("今日！")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.green)
                        } else {
                            HStack(spacing: 16) {
                                TimeUnitView(value: context.state.daysRemaining, unit: "日")
                                TimeUnitView(value: context.state.hoursRemaining, unit: "時間")
                                TimeUnitView(value: context.state.minutesRemaining, unit: "分")
                            }
                        }
                    }
                }
            } compactLeading: {
                // コンパクト表示（左）
                Image(systemName: "calendar")
                    .foregroundColor(Color(context.attributes.eventColor))
            } compactTrailing: {
                // コンパクト表示（右）
                if context.state.isPast {
                    Text("+\(context.state.daysPassed)日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(context.state.daysRemaining)日")
                        .font(.caption)
                        .bold()
                }
            } minimal: {
                // 最小表示
                if context.state.isPast {
                    Text("+\(context.state.daysPassed)")
                        .font(.caption2)
                } else {
                    Text("\(context.state.daysRemaining)")
                        .font(.caption2)
                        .bold()
                }
            }
            .keylineTint(Color(context.attributes.eventColor))
        }
    }
}

// MARK: - Lock Screen View
struct LockScreenView: View {
    let context: ActivityViewContext<CountdownActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.eventTitle)
                    .font(.headline)
                    .lineLimit(1)

                if context.state.isPast {
                    Text("\(context.state.daysPassed)日経過")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(context.attributes.targetDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if context.state.isPast {
                VStack {
                    Text("\(context.state.daysPassed)")
                        .font(.title)
                        .bold()
                    Text("日経過")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if context.state.daysRemaining == 0 {
                Text("今日！")
                    .font(.title)
                    .bold()
                    .foregroundColor(.green)
            } else {
                HStack(spacing: 8) {
                    CompactTimeUnit(value: context.state.daysRemaining, unit: "日")
                    CompactTimeUnit(value: context.state.hoursRemaining, unit: "時")
                    CompactTimeUnit(value: context.state.minutesRemaining, unit: "分")
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color(context.attributes.eventColor).opacity(0.2))
        .activitySystemActionForegroundColor(.primary)
    }
}

// MARK: - Supporting Views
struct TimeUnitView: View {
    let value: Int
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2)
                .bold()
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct CompactTimeUnit: View {
    let value: Int
    let unit: String

    var body: some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.title3)
                .bold()
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct CountdownBadge: View {
    let state: CountdownActivityAttributes.ContentState

    var body: some View {
        if state.isPast {
            Text("+\(state.daysPassed)")
                .font(.title3)
                .bold()
                .foregroundColor(.secondary)
        } else {
            Text("\(state.daysRemaining)")
                .font(.title3)
                .bold()
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(_ colorName: String) {
        switch colorName.lowercased() {
        case "red": self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green": self = .green
        case "blue": self = .blue
        case "purple": self = .purple
        case "pink": self = .pink
        default: self = .blue
        }
    }
}

// MARK: - Preview
extension CountdownActivityAttributes {
    fileprivate static var preview: CountdownActivityAttributes {
        CountdownActivityAttributes(
            eventId: "preview",
            eventTitle: "誕生日パーティー",
            eventColor: "blue",
            targetDate: Date().addingTimeInterval(86400 * 7)
        )
    }
}

extension CountdownActivityAttributes.ContentState {
    fileprivate static var upcoming: CountdownActivityAttributes.ContentState {
        CountdownActivityAttributes.ContentState(
            daysRemaining: 7,
            hoursRemaining: 12,
            minutesRemaining: 30,
            isPast: false,
            daysPassed: 0
        )
    }

    fileprivate static var today: CountdownActivityAttributes.ContentState {
        CountdownActivityAttributes.ContentState(
            daysRemaining: 0,
            hoursRemaining: 5,
            minutesRemaining: 30,
            isPast: false,
            daysPassed: 0
        )
    }

    fileprivate static var past: CountdownActivityAttributes.ContentState {
        CountdownActivityAttributes.ContentState(
            daysRemaining: 0,
            hoursRemaining: 0,
            minutesRemaining: 0,
            isPast: true,
            daysPassed: 3
        )
    }
}

#Preview("Notification", as: .content, using: CountdownActivityAttributes.preview) {
    countDownWidgetsLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState.upcoming
    CountdownActivityAttributes.ContentState.today
    CountdownActivityAttributes.ContentState.past
}
