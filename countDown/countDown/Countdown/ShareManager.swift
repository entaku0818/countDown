import SwiftUI
import UIKit

class ShareManager: ObservableObject {
    static let shared = ShareManager()
    
    private init() {}
    
    func shareEvent(title: String, date: Date, description: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let dateString = dateFormatter.string(from: date)
        var shareText = "\(title)\n開催日時: \(dateString)"
        
        if let description = description {
            shareText += "\n\n\(description)"
        }
        
        let activityItems: [Any] = [shareText]
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
} 