import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let user: User?
    
    // デバッグモードフラグ（実際の環境では false にする）
    #if DEBUG
    @State private var isDebugMode = true
    #else
    @State private var isDebugMode = false
    #endif
    
    var body: some View {
        List {
            Section("一般設定") {
                
                NavigationLink(destination: Text("利用規約画面をここに実装")) {
                    Text("利用規約")
                }
                
                NavigationLink(destination: Text("プライバシーポリシー画面をここに実装")) {
                    Text("プライバシーポリシー")
                }
            }
            
            #if DEBUG
            Section {
                Toggle("デバッグモード", isOn: $isDebugMode)
            }
            #endif
            
            // デバッグモードの場合のみユーザー情報を表示
            if isDebugMode, let user = user {
                Section("デバッグ情報") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ユーザー情報")
                            .font(.headline)
                        
                        HStack {
                            Text("ユーザータイプ:")
                            Spacer()
                            Text(user.isAnonymous ? "匿名ユーザー" : "認証済みユーザー")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("ユーザーID:")
                            Spacer()
                            Text(user.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button(action: {
                    // アプリ情報ダイアログを表示
                }) {
                    Text("アプリについて")
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    // アプリの評価画面を表示
                }) {
                    Text("アプリを評価する")
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("設定")
    }
} 