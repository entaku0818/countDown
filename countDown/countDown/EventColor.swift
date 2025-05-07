import SwiftUI

enum EventColor: String, CaseIterable, Codable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    
    var colorValue: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
    
    static func from(string: String) -> EventColor {
        return EventColor(rawValue: string) ?? .blue
    }
}

extension Color {
    init(stringValue: String) {
        let eventColor = EventColor.from(string: stringValue)
        self = eventColor.colorValue
    }
} 