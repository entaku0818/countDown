const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// 定期的な通知処理のみを実装
// スケジュールされたイベントの通知を送信するCloud Function
exports.sendEventNotifications = functions.pubsub.schedule("every 1 hours").onRun(async () => {
  const now = admin.firestore.Timestamp.now();
  const oneHourLater = new admin.firestore.Timestamp(now.seconds + 3600, now.nanoseconds);
  
  console.log(`通知チェック: ${new Date(now.seconds * 1000).toLocaleString()} から ${new Date(oneHourLater.seconds * 1000).toLocaleString()} までのイベントを検索`);
  
  try {
    // 今後1時間以内に通知が必要なイベントを取得
    const snapshot = await admin.firestore()
      .collection("events")
      .where("notificationDate", ">=", now)
      .where("notificationDate", "<=", oneHourLater)
      .get();
    
    if (snapshot.empty) {
      console.log("通知予定のイベントはありません");
      return null;
    }
    
    console.log(`${snapshot.size}件の通知対象イベントを見つけました`);
    
    const notifications = [];
    
    snapshot.forEach((doc) => {
      const event = doc.data();
      const userId = event.userId;
      
      // 通知が有効かチェック
      if (!event.notificationEnabled) {
        console.log(`イベント(${doc.id})の通知は無効です`);
        return;
      }
      
      // ユーザーデータを取得してFCMトークンを確認
      notifications.push(
        admin.firestore()
          .collection("users")
          .doc(userId)
          .get()
          .then((userDoc) => {
            const userData = userDoc.data();
            if (!userData || !userData.fcmToken) {
              console.log(`ユーザー(${userId})にFCMトークンが見つかりませんでした`);
              return;
            }
            
            // 通知メッセージを構成
            const message = {
              token: userData.fcmToken,
              notification: {
                title: "イベント通知",
                body: `「${event.title}」まであと${event.daysRemaining}日です`,
              },
              data: {
                eventId: doc.id,
                eventTitle: event.title,
                eventDate: event.date.toDate().toString()
              },
              // 通知の優先度設定
              android: {
                priority: "high",
              },
              apns: {
                payload: {
                  aps: {
                    contentAvailable: true,
                    sound: "default",
                  }
                }
              }
            };
            
            // FCMで通知を送信
            return admin.messaging().send(message)
              .then((response) => {
                console.log(`通知を送信しました: ${response}`);
                
                // 通知履歴を保存
                return admin.firestore()
                  .collection("notificationHistory")
                  .add({
                    eventId: doc.id,
                    eventTitle: event.title,
                    userId: userId,
                    sentAt: admin.firestore.Timestamp.now(),
                    status: "sent"
                  });
              })
              .catch((error) => {
                console.error(`通知送信エラー: ${error}`);
                // エラー情報を保存
                return admin.firestore()
                  .collection("notificationHistory")
                  .add({
                    eventId: doc.id,
                    eventTitle: event.title,
                    userId: userId,
                    sentAt: admin.firestore.Timestamp.now(),
                    status: "failed",
                    errorMessage: error.message
                  });
              });
          })
          .catch((error) => {
            console.error(`ユーザー情報取得エラー: ${error}`);
          })
      );
    });
    
    await Promise.all(notifications);
    console.log("全ての通知処理が完了しました");
    
  } catch (error) {
    console.error(`通知処理中にエラーが発生しました: ${error}`);
  }
  
  return null;
});

// テスト用端末に通知を送信するテスト関数
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  try {
    // CORSヘッダーの設定
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    
    // OPTIONSリクエスト（プリフライト）への対応
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    
    // リクエストボディからデータを取得
    const { fcmToken, title, body, eventId, eventTitle, daysRemaining } = req.body;
    
    if (!fcmToken) {
      res.status(400).json({ 
        success: false, 
        error: "FCMトークンが必要です" 
      });
      return;
    }
    
    // 通知メッセージのデフォルト値を設定
    const notificationTitle = title || "テスト通知";
    const notificationBody = body || "これはテスト通知です";
    const eventData = {
      id: eventId || "test-event-id",
      title: eventTitle || "テストイベント",
      daysRemaining: daysRemaining || 7
    };
    
    // メッセージを構成
    const message = {
      token: fcmToken,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        eventId: eventData.id,
        eventTitle: eventData.title,
        daysRemaining: eventData.daysRemaining.toString(),
        isTest: "true"
      },
      // 通知の優先度設定
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: "default",
          }
        }
      }
    };
    
    // FCMで通知を送信
    const response = await admin.messaging().send(message);
    console.log(`テスト通知を送信しました: ${response}`);
    
    // 送信履歴を保存
    await admin.firestore()
      .collection("notificationHistory")
      .add({
        eventId: eventData.id,
        eventTitle: eventData.title,
        fcmToken: fcmToken,
        sentAt: admin.firestore.Timestamp.now(),
        status: "sent",
        isTest: true
      });
    
    // 成功レスポンスを返す
    res.status(200).json({
      success: true,
      messageId: response,
      message: "テスト通知が送信されました"
    });
    
  } catch (error) {
    console.error(`テスト通知送信エラー: ${error}`);
    
    // エラーレスポンスを返す
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
}); 