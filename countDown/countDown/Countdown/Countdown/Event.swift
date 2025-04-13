import Foundation
import SwiftUI

struct Event: Equatable, Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var color: String
    var note: String
    var displayFormat: DisplayFormat
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        color: String = "blue",
        note: String = "",
        displayFormat: DisplayFormat = DisplayFormat()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.color = color
        self.note = note
        self.displayFormat = displayFormat
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day ?? 0
    }
    
    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    var isPast: Bool {
        return Date() > date
    }
} 