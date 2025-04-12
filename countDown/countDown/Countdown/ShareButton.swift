import SwiftUI

struct ShareButton: View {
    let title: String
    let date: Date
    let description: String?
    
    var body: some View {
        Button(action: {
            ShareManager.shared.shareEvent(title: title, date: date, description: description)
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("共有")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

#Preview {
    ShareButton(
        title: "サンプルイベント",
        date: Date(),
        description: "これはサンプルのイベントです"
    )
} 