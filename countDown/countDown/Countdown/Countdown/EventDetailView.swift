import SwiftUI
import ComposableArchitecture

struct EventDetailView: View {
    let event: Event
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    CountdownDisplay(event: event)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                    
                    Text(event.title)
                        .font(.title)
                        .bold()
                    
                    if !event.note.isEmpty {
                        Text(event.note)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Section("日付") {
                HStack {
                    Text("日付")
                    Spacer()
                    Text(event.date.formatted(date: .long, time: .omitted))
                        .foregroundColor(.secondary)
                }
            }
            
            Section("表示形式") {
                HStack {
                    Text("表示形式")
                    Spacer()
                    Text(event.displayFormat.style.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("色")
                    Spacer()
                    Circle()
                        .fill(Color(stringValue: event.color))
                        .frame(width: 20, height: 20)
                }
            }
            
            Section {
                ShareButton(
                    title: event.title,
                    date: event.date,
                    description: event.note
                )
            }
        }
        .navigationTitle("イベント詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: Event(
            title: "サンプルイベント",
            date: Date(),
            color: "blue", note: "これはサンプルのイベントです。",
            displayFormat: DisplayFormat(style: .days)
        ))
    }
} 
