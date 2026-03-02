//
//  countDownTests.swift
//  countDownTests
//
//  Created by 遠藤拓弥 on 2025/04/06.
//

import Testing
import Foundation
@testable import countDown

// MARK: - Event Tests
struct EventTests {

    @Test func eventDaysRemaining() async throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let event = Event(title: "テストイベント", date: futureDate)

        #expect(event.daysRemaining >= 9 && event.daysRemaining <= 10)
        #expect(event.isPast == false)
    }

    @Test func eventIsPast() async throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let event = Event(title: "過去のイベント", date: pastDate)

        #expect(event.isPast == true)
        #expect(event.daysRemaining < 0)
    }

    @Test func eventDaysPassed() async throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let event = Event(title: "カウントアップイベント", date: pastDate)

        #expect(event.daysPassed >= 9 && event.daysPassed <= 10)
        #expect(event.isPast == true)
    }

    @Test func eventIsToday() async throws {
        let event = Event(title: "今日のイベント", date: Date())

        #expect(event.isToday == true)
    }

    @Test func eventIsWithinSevenDays() async throws {
        let nearDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let event = Event(title: "近いイベント", date: nearDate)

        #expect(event.isWithinSevenDays == true)
    }

    @Test func eventNotWithinSevenDays() async throws {
        let farDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let event = Event(title: "遠いイベント", date: farDate)

        #expect(event.isWithinSevenDays == false)
    }
}

// MARK: - NotificationSettings Tests
struct NotificationSettingsTests {

    @Test func notificationTimingDescription() async throws {
        #expect(NotificationTiming.none.description == "通知なし")
        #expect(NotificationTiming.sameDay.description == "当日")
        #expect(NotificationTiming.dayBefore.description == "1日前")
        #expect(NotificationTiming.weekBefore.description == "1週間前")
        #expect(NotificationTiming.monthBefore.description == "1ヶ月前")
        #expect(NotificationTiming.custom(days: 3).description == "3日前")
    }

    @Test func notificationTimingIdentifier() async throws {
        #expect(NotificationTiming.none.identifier == "none")
        #expect(NotificationTiming.sameDay.identifier == "sameDay")
        #expect(NotificationTiming.dayBefore.identifier == "dayBefore")
        #expect(NotificationTiming.custom(days: 5).identifier == "custom_5")
    }

    @Test func notificationDateCalculation() async throws {
        let eventDate = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 14, minute: 0))!

        // 当日の通知は朝9時
        let sameDayNotification = NotificationTiming.sameDay.notificationDate(for: eventDate)
        #expect(sameDayNotification != nil)

        let sameDayComponents = Calendar.current.dateComponents([.year, .month, .day, .hour], from: sameDayNotification!)
        #expect(sameDayComponents.year == 2026)
        #expect(sameDayComponents.month == 6)
        #expect(sameDayComponents.day == 15)
        #expect(sameDayComponents.hour == 9)

        // 1日前の通知
        let dayBeforeNotification = NotificationTiming.dayBefore.notificationDate(for: eventDate)
        #expect(dayBeforeNotification != nil)

        let dayBeforeComponents = Calendar.current.dateComponents([.day], from: dayBeforeNotification!)
        #expect(dayBeforeComponents.day == 14)
    }

    @Test func notificationSettingsHasNotification() async throws {
        let settings = NotificationSettings(
            isEnabled: true,
            timing: .dayBefore,
            eventId: UUID()
        )

        #expect(settings.hasNotification == true)
    }

    @Test func notificationSettingsDisabled() async throws {
        let settings = NotificationSettings(
            isEnabled: false,
            timing: .dayBefore,
            eventId: UUID()
        )

        #expect(settings.hasNotification == false)
    }
}

// MARK: - WidgetEvent Tests
struct WidgetEventTests {

    @Test func widgetEventDaysRemaining() async throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let widgetEvent = WidgetEvent(
            id: UUID(),
            title: "ウィジェットイベント",
            date: futureDate,
            color: "blue"
        )

        #expect(widgetEvent.daysRemaining >= 6 && widgetEvent.daysRemaining <= 7)
        #expect(widgetEvent.isPast == false)
    }

    @Test func widgetEventDaysPassed() async throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let widgetEvent = WidgetEvent(
            id: UUID(),
            title: "過去のウィジェットイベント",
            date: pastDate,
            color: "red"
        )

        #expect(widgetEvent.daysPassed >= 9 && widgetEvent.daysPassed <= 10)
        #expect(widgetEvent.isPast == true)
    }

    @Test func widgetEventIsToday() async throws {
        let widgetEvent = WidgetEvent(
            id: UUID(),
            title: "今日のウィジェットイベント",
            date: Date(),
            color: "green"
        )

        #expect(widgetEvent.isToday == true)
    }

    @Test func widgetEventCodable() async throws {
        let originalEvent = WidgetEvent(
            id: UUID(),
            title: "エンコードテスト",
            date: Date(),
            color: "purple"
        )

        // エンコード
        let encoded = try JSONEncoder().encode(originalEvent)
        #expect(encoded.count > 0)

        // デコード
        let decoded = try JSONDecoder().decode(WidgetEvent.self, from: encoded)
        #expect(decoded.id == originalEvent.id)
        #expect(decoded.title == originalEvent.title)
        #expect(decoded.color == originalEvent.color)
    }
}

// MARK: - RepeatType Tests
struct RepeatTypeTests {

    @Test func repeatTypeNoneReturnsSameDate() async throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let event = Event(title: "繰り返しなし", date: futureDate, repeatType: .none)

        #expect(event.nextOccurrenceDate == futureDate)
        #expect(event.displayDate == futureDate)
    }

    @Test func repeatTypeNoneForPastEventReturnsPastDate() async throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let event = Event(title: "繰り返しなし過去", date: pastDate, repeatType: .none)

        #expect(event.nextOccurrenceDate == pastDate)
        #expect(event.displayDate == pastDate)
    }

    @Test func repeatTypeYearlyReturnsFutureDate() async throws {
        let pastDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let event = Event(title: "毎年イベント", date: pastDate, repeatType: .yearly)

        let nextDate = event.nextOccurrenceDate
        #expect(nextDate > Date())
        #expect(event.displayDate == nextDate)
    }

    @Test func repeatTypeMonthlyReturnsFutureDate() async throws {
        let pastDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let event = Event(title: "毎月イベント", date: pastDate, repeatType: .monthly)

        let nextDate = event.nextOccurrenceDate
        #expect(nextDate > Date())
    }

    @Test func repeatTypeWeeklyReturnsFutureDate() async throws {
        let pastDate = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
        let event = Event(title: "毎週イベント", date: pastDate, repeatType: .weekly)

        let nextDate = event.nextOccurrenceDate
        #expect(nextDate > Date())
    }

    @Test func repeatTypeYearlyPreservesMonthAndDay() async throws {
        // 誕生日など月日が保持されることを確認
        let pastDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let event = Event(title: "誕生日", date: pastDate, repeatType: .yearly)

        let nextDate = event.nextOccurrenceDate
        let pastComponents = Calendar.current.dateComponents([.month, .day], from: pastDate)
        let nextComponents = Calendar.current.dateComponents([.month, .day], from: nextDate)

        #expect(pastComponents.month == nextComponents.month)
        #expect(pastComponents.day == nextComponents.day)
    }

    @Test func repeatTypeEncodeDecode() async throws {
        let event = Event(title: "繰り返しテスト", date: Date(), repeatType: .yearly)

        let encoded = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: encoded)

        #expect(decoded.repeatType == .yearly)
    }

    @Test func repeatTypeDefaultIsNone() async throws {
        let event = Event(title: "デフォルト", date: Date())
        #expect(event.repeatType == .none)
    }

    // 未来のイベントは繰り返し設定があっても日付が進まない
    @Test func repeatTypeFutureEventNotAdvanced() async throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let event = Event(title: "未来の毎年イベント", date: futureDate, repeatType: .yearly)

        #expect(event.nextOccurrenceDate == futureDate)
        #expect(event.displayDate == futureDate)
    }

    // 毎週：元の曜日が保持される
    @Test func repeatTypeWeeklyPreservesDayOfWeek() async throws {
        let pastDate = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: Date())!
        let event = Event(title: "毎週イベント", date: pastDate, repeatType: .weekly)

        let nextDate = event.nextOccurrenceDate
        let originalWeekday = Calendar.current.component(.weekday, from: pastDate)
        let nextWeekday = Calendar.current.component(.weekday, from: nextDate)

        #expect(originalWeekday == nextWeekday)
    }

    // 毎月：元の日付（何日か）が保持される
    @Test func repeatTypeMonthlyPreservesDayOfMonth() async throws {
        let pastDate = Calendar.current.date(byAdding: .month, value: -5, to: Date())!
        let event = Event(title: "毎月イベント", date: pastDate, repeatType: .monthly)

        let nextDate = event.nextOccurrenceDate
        let originalDay = Calendar.current.component(.day, from: pastDate)
        let nextDay = Calendar.current.component(.day, from: nextDate)

        #expect(originalDay == nextDay)
    }

    // 旧フォーマット（repeatTypeなし）からのデコード互換性
    @Test func repeatTypeBackwardCompatibilityDecode() async throws {
        let jsonWithoutRepeatType = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "title": "旧データ",
            "date": 1000000,
            "color": "blue",
            "note": "",
            "displayFormat": {"timeDisplayMode": "日数のみ", "style": "日数"},
            "notificationSettings": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Event.self, from: jsonWithoutRepeatType)
        #expect(decoded.repeatType == .none)
    }

    // displayDate のソート：繰り返しイベントが正しい順序になる
    @Test func repeatTypeDisplayDateSorting() async throws {
        let calendar = Calendar.current

        // 1年前の誕生日（毎年繰り返し）→ 次回は未来
        let birthdayBase = calendar.date(byAdding: .year, value: -1, to: Date())!
        let birthdayEvent = Event(title: "誕生日", date: birthdayBase, repeatType: .yearly)

        // 3日後のイベント（繰り返しなし）
        let soonDate = calendar.date(byAdding: .day, value: 3, to: Date())!
        let soonEvent = Event(title: "近いイベント", date: soonDate, repeatType: .none)

        // 30日後のイベント（繰り返しなし）
        let farDate = calendar.date(byAdding: .day, value: 30, to: Date())!
        let farEvent = Event(title: "遠いイベント", date: farDate, repeatType: .none)

        let events = [farEvent, birthdayEvent, soonEvent]
        let sorted = events.sorted { $0.displayDate < $1.displayDate }

        // soonEvent(3日後) < birthdayEvent(次回) or farEvent(30日後) の順になるはず
        #expect(sorted[0].title == "近いイベント")
    }
}

// MARK: - Event Codable Tests
struct EventCodableTests {

    @Test func eventEncodeDecode() async throws {
        let originalEvent = Event(
            title: "コード化テスト",
            date: Date(),
            color: "blue",
            note: "テストノート"
        )

        // エンコード
        let encoded = try JSONEncoder().encode(originalEvent)
        #expect(encoded.count > 0)

        // デコード
        let decoded = try JSONDecoder().decode(Event.self, from: encoded)
        #expect(decoded.id == originalEvent.id)
        #expect(decoded.title == originalEvent.title)
        #expect(decoded.color == originalEvent.color)
        #expect(decoded.note == originalEvent.note)
    }

    @Test func eventWithNotificationSettings() async throws {
        let eventId = UUID()
        let settings = NotificationSettings(
            isEnabled: true,
            timing: .dayBefore,
            eventId: eventId
        )

        let event = Event(
            id: eventId,
            title: "通知付きイベント",
            date: Date().addingTimeInterval(86400 * 7),
            notificationSettings: [settings]
        )

        #expect(event.hasEnabledNotifications == true)
        #expect(event.notificationSettings.count == 1)
    }
}
