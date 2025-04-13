import Foundation

struct DisplayFormat: Equatable, Codable {
    var showDays: Bool = true
    var showHours: Bool = false
    var showMinutes: Bool = false
    var showSeconds: Bool = false
    var style: CountdownStyle = .days
    
    enum CountdownStyle: String, CaseIterable, Codable {
        case days = "日数"
        case progress = "進捗バー"
        case circle = "サークル"
    }
} 