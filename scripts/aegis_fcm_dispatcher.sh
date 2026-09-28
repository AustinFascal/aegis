#!/bin/bash
# ==============================================================================
# AEGIS Real-Time Security Alert Dispatcher (Server-Side)
# Sends instant high-priority push notifications to Aegis Android App via FCM
# ==============================================================================

IP="${1:-Unknown IP}"
SERVICE="${2:-sshd}"
REASON="${3:-Brute-force incursion detected}"
FAIL_COUNT="${4:-5}"
FCM_SERVER_KEY="${FCM_SERVER_KEY:-YOUR_FCM_SERVER_KEY}"
FCM_TOPIC="${FCM_TOPIC:-aegis_alerts}"

echo "[Aegis Dispatcher] Sending push alert for IP: $IP on $SERVICE..."

# JSON Payload matching Aegis Android Notification Service
PAYLOAD=$(cat <<JSON
{
  "to": "/topics/$FCM_TOPIC",
  "priority": "high",
  "data": {
    "title": "🚨 CRITICAL: Incursion on $SERVICE",
    "body": "IP $IP failed $FAIL_COUNT attempts. Reason: $REASON",
    "ip": "$IP",
    "service": "$SERVICE",
    "reason": "$REASON",
    "riskScore": "95"
  },
  "notification": {
    "title": "🚨 CRITICAL: Incursion on $SERVICE",
    "body": "IP $IP failed $FAIL_COUNT attempts. Reason: $REASON",
    "sound": "default",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
JSON
)

# Dispatch via curl
curl -s -X POST "https://fcm.googleapis.com/fcm/send" \
  -H "Authorization: key=$FCM_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

echo "[Aegis Dispatcher] Dispatched alert for $IP."
