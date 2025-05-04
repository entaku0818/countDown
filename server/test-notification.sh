#!/bin/bash

# 色の定義
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 使用方法を表示する関数
show_usage() {
  echo -e "${BLUE}CountDown アプリ 通知テストスクリプト${NC}"
  echo ""
  echo "使用方法:"
  echo "  ./test-notification.sh [オプション]"
  echo ""
  echo "オプション:"
  echo "  -t, --token FCM_TOKEN     FCMトークン（必須）"
  echo "  -T, --title タイトル      通知タイトル（デフォルト: テスト通知）"
  echo "  -m, --message メッセージ   通知メッセージ（デフォルト: これはテスト通知です）"
  echo "  -e, --event イベント名    イベントタイトル（デフォルト: テストイベント）"
  echo "  -d, --days 日数           残り日数（デフォルト: 7）"
  echo "  -h, --help                このヘルプメッセージを表示"
  echo ""
  echo "例:"
  echo "  ./test-notification.sh -t 'FCMトークン' -T 'イベント通知' -m '明日が締切です！' -e '重要会議' -d 1"
}

# 引数の解析
TOKEN=""
TITLE="テスト通知"
MESSAGE="これはテスト通知です"
EVENT="テストイベント"
DAYS=7

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--token)
      TOKEN="$2"
      shift 2
      ;;
    -T|--title)
      TITLE="$2"
      shift 2
      ;;
    -m|--message)
      MESSAGE="$2"
      shift 2
      ;;
    -e|--event)
      EVENT="$2"
      shift 2
      ;;
    -d|--days)
      DAYS="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo -e "${RED}エラー: 不明なオプション '$1'${NC}"
      show_usage
      exit 1
      ;;
  esac
done

# トークンが指定されているか確認
if [ -z "$TOKEN" ]; then
  echo -e "${RED}エラー: FCMトークンが指定されていません。-t または --token オプションで指定してください。${NC}"
  show_usage
  exit 1
fi

# デプロイ後のCloud FunctionsのURL
FUNCTION_URL="https://us-central1-countdown-336cf.cloudfunctions.net/sendTestNotification"

echo -e "${BLUE}通知送信リクエストを準備中...${NC}"
echo "FCMトークン: ${TOKEN:0:20}... (一部表示)"
echo "タイトル: $TITLE"
echo "本文: $MESSAGE"
echo "イベント: $EVENT"
echo "残り日数: $DAYS"

# JSONリクエストボディの構築
JSON_DATA=$(cat <<EOF
{
  "fcmToken": "$TOKEN",
  "title": "$TITLE",
  "body": "$MESSAGE",
  "eventTitle": "$EVENT",
  "daysRemaining": $DAYS
}
EOF
)

echo -e "${BLUE}通知テストを実行中...${NC}"

# curlリクエストの実行
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA" \
  "$FUNCTION_URL")

# レスポンスの解析と表示
if echo "$RESPONSE" | grep -q '"success":true'; then
  echo -e "${GREEN}成功: 通知が送信されました！${NC}"
  echo "$RESPONSE" | sed 's/,/,\n/g; s/{/{\n/g; s/}/\n}/g' # 読みやすく整形
else
  echo -e "${RED}エラー: 通知の送信に失敗しました${NC}"
  echo "$RESPONSE" | sed 's/,/,\n/g; s/{/{\n/g; s/}/\n}/g' # 読みやすく整形
fi

# シンプルなcurlコマンドの表示（参考用）
echo -e "\n${BLUE}同等のcurlコマンド（コピペして使用可能）:${NC}"
echo "curl -X POST \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"fcmToken\":\"$TOKEN\",\"title\":\"$TITLE\",\"body\":\"$MESSAGE\",\"eventTitle\":\"$EVENT\",\"daysRemaining\":$DAYS}' \\"
echo "  $FUNCTION_URL" 