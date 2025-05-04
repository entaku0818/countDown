import Foundation
import UIKit

/// Firebase Cloud Functionsを使用してテスト通知を送信するクラス
class NotificationTester {
    
    /// テスト通知を送信するCloud Function URL
    private let functionUrl = "https://us-central1-countdown-336cf.cloudfunctions.net/sendTestNotification"
    
    /// FCMトークンを使用してテスト通知を送信する
    /// - Parameters:
    ///   - fcmToken: テスト端末のFCMトークン
    ///   - title: 通知のタイトル (オプション)
    ///   - body: 通知の本文 (オプション)
    ///   - eventTitle: イベントタイトル (オプション)
    ///   - daysRemaining: イベントまでの残り日数 (オプション)
    ///   - completion: 結果コールバック (成功/失敗とメッセージ)
    func sendTestNotification(
        fcmToken: String,
        title: String = "テスト通知",
        body: String = "これはテスト通知です",
        eventTitle: String = "テストイベント",
        daysRemaining: Int = 7,
        completion: @escaping (Bool, String?) -> Void
    ) {
        // URLの作成
        guard let url = URL(string: functionUrl) else {
            completion(false, "不正なURL")
            return
        }
        
        // URLRequestの作成
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // リクエストボディの作成
        let body: [String: Any] = [
            "fcmToken": fcmToken,
            "title": title,
            "body": body,
            "eventTitle": eventTitle,
            "daysRemaining": daysRemaining
        ]
        
        // JSONシリアライズ
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "リクエストの作成に失敗しました: \(error.localizedDescription)")
            return
        }
        
        // リクエスト送信
        URLSession.shared.dataTask(with: request) { data, response, error in
            // エラー処理
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "エラー: \(error.localizedDescription)")
                }
                return
            }
            
            // レスポンスの確認
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "不正なレスポンス")
                }
                return
            }
            
            // ステータスコードの確認
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(false, "HTTP エラー: \(httpResponse.statusCode)")
                }
                return
            }
            
            // データの確認
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false, "データが受信できませんでした")
                }
                return
            }
            
            // JSONパース
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let success = json["success"] as? Bool ?? false
                    let message = json["message"] as? String ?? "Unknown"
                    
                    DispatchQueue.main.async {
                        completion(success, message)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "レスポンスの解析に失敗しました")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "JSONの解析に失敗しました: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
}

// 使用例
class NotificationTestViewController: UIViewController {
    
    private let tester = NotificationTester()
    
    // テスト通知ボタンのアクション
    @IBAction func sendTestNotificationTapped(_ sender: UIButton) {
        // アプリで取得したFCMトークンを使用
        let fcmToken = "YOUR_FCM_TOKEN_HERE" 
        
        // インジケータの表示
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        // テスト通知の送信
        tester.sendTestNotification(
            fcmToken: fcmToken,
            title: "カウントダウン通知",
            body: "イベントが近づいています！",
            eventTitle: "重要なイベント",
            daysRemaining: 3
        ) { success, message in
            // インジケータを非表示
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            
            // 結果の表示
            let alert = UIAlertController(
                title: success ? "成功" : "エラー",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

// SwiftUIでの実装例
import SwiftUI

struct NotificationTestView: View {
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private let tester = NotificationTester()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("テスト通知")
                .font(.title)
                .fontWeight(.bold)
            
            Button(action: {
                sendTestNotification()
            }) {
                Text("通知を送信")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func sendTestNotification() {
        // アプリで取得したFCMトークンを使用
        let fcmToken = "YOUR_FCM_TOKEN_HERE"
        
        isLoading = true
        
        tester.sendTestNotification(
            fcmToken: fcmToken,
            title: "カウントダウン通知",
            body: "イベントが近づいています！",
            eventTitle: "重要なイベント",
            daysRemaining: 3
        ) { success, message in
            isLoading = false
            alertTitle = success ? "成功" : "エラー"
            alertMessage = message ?? "不明なエラー"
            showAlert = true
        }
    }
} 