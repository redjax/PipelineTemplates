#!/usr/bin/env bash
set -Eeuo pipefail

########################################################
# Gotify Notification Script                           #
#                                                      #
# This script controls sending notifications to        #
# a Gotify server. It can handle simple notifications. #
# and more complex ones with JSON payloads & images.   #
#                                                      #
# It was designed to be called from a CI/CD pipeline.  #
########################################################

GOTIFY_URL="${GOTIFY_URL:?GOTIFY_URL is required}"
TOKEN="${GOTIFY_TOKEN:?GOTIFY_TOKEN is required}"

TITLE="${TITLE:-}"
MESSAGE="${MESSAGE:?MESSAGE is required}"
PRIORITY="${PRIORITY:-0}"

USE_JSON="${USE_JSON:-true}"

CONTENT_TYPE="${CONTENT_TYPE:-text/plain}"
CLICK_URL="${CLICK_URL:-}"
BIG_IMAGE_URL="${BIG_IMAGE_URL:-}"
INTENT_URL="${INTENT_URL:-}"

USER_EXTRAS="${USER_EXTRAS:-{}}"
RAW_JSON_PAYLOAD="${RAW_JSON_PAYLOAD:-}"

USER_AGENT="${USER_AGENT:-redjax/PipelineTemplates}"
DEBUG="${DEBUG:-false}"

UA_HEADER=(-H "User-Agent: ${USER_AGENT}")

function log() {
  echo "[INFO] $*"
}

function debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "[DEBUG] $*"
  fi
}

function usage() {
  cat <<'EOF'
Gotify Notification CLI

USAGE:
  send-notification.sh [OPTIONS]

REQUIRED:
  -m, --message        Notification message

OPTIONAL:
  -u, --gotify-url     Gotify base URL (or env GOTIFY_URL)
  -t, --token          Gotify token (or env GOTIFY_TOKEN)

  --title              Notification title
  --priority           Priority (default: 0)

  --use-json           true|false (default: true)

  --content-type       default: text/plain
  --click-url
  --big-image-url
  --intent-url

  --extras-json        JSON string (default: {})
  --raw-payload        Override full JSON payload

  --user-agent         default: redjax/PipelineTemplates
  --debug              Enable debug logs

  -h, --help           Show this help

ENV FALLBACKS:
  GOTIFY_URL
  GOTIFY_TOKEN
  TITLE
  MESSAGE
  PRIORITY
  USE_JSON
  USER_AGENT
  DEBUG

EXAMPLES:

  send-notification.sh \
    --gotify-url https://gotify.local \
    --token abc123 \
    --message "Hello"

  GOTIFY_URL=https://... GOTIFY_TOKEN=... \
  send-notification.sh -m "CI done"

EOF
}

## Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
  -u | --gotify-url)
    GOTIFY_URL="$2"
    shift 2
    ;;
  -t | --token)
    TOKEN="$2"
    shift 2
    ;;
  -m | --message)
    MESSAGE="$2"
    shift 2
    ;;
  --title)
    TITLE="$2"
    shift 2
    ;;
  --priority)
    PRIORITY="$2"
    shift 2
    ;;
  --use-json)
    USE_JSON="$2"
    shift 2
    ;;
  --content-type)
    CONTENT_TYPE="$2"
    shift 2
    ;;
  --click-url)
    CLICK_URL="$2"
    shift 2
    ;;
  --big-image-url)
    BIG_IMAGE_URL="$2"
    shift 2
    ;;
  --intent-url)
    INTENT_URL="$2"
    shift 2
    ;;
  --extras-json)
    USER_EXTRAS="$2"
    shift 2
    ;;
  --raw-payload)
    RAW_JSON_PAYLOAD="$2"
    shift 2
    ;;
  --user-agent)
    USER_AGENT="$2"
    shift 2
    ;;
  --debug)
    DEBUG="true"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

## Validate required inputs
[[ -n "$GOTIFY_URL" ]] || {
  echo "ERROR: GOTIFY_URL required"
  exit 1
}
[[ -n "$TOKEN" ]] || {
  echo "ERROR: GOTIFY_TOKEN required"
  exit 1
}
[[ -n "$MESSAGE" ]] || {
  echo "ERROR: MESSAGE required"
  exit 1
}

## Debug URL
debug "Gotify URL: $GOTIFY_URL"

## Validate JSON inputs
echo "$USER_EXTRAS" | jq empty >/dev/null 2>&1 || {
  echo "ERROR: USER_EXTRAS invalid JSON"
  exit 1
}
if [[ -n "$RAW_JSON_PAYLOAD" ]]; then
  echo "$RAW_JSON_PAYLOAD" | jq empty >/dev/null 2>&1 || {
    echo "ERROR: RAW_JSON_PAYLOAD invalid JSON"
    exit 1
  }
fi

## Normalize priority
PRIORITY="${PRIORITY:-0}"
[[ "$PRIORITY" =~ ^[0-9]+$ ]] || PRIORITY=0

## Build curl flags dynamically
CURL_FLAGS=(
  --connect-timeout 5
  --max-time 15
  --fail
  --show-error
  --retry 3
  --retry-delay 5
  -X POST
)
if [[ "$DEBUG" != "true" ]]; then
  CURL_FLAGS+=(--silent)
fi

## Multipart mode
if [[ "$USE_JSON" != "true" ]]; then
  log "Sending multipart notification"
  curl "${CURL_FLAGS[@]}" \
    "${GOTIFY_URL}/message?token=${TOKEN}" \
    "${UA_HEADER[@]}" \
    -F "message=${MESSAGE}" \
    ${TITLE:+-F "title=${TITLE}"} \
    ${PRIORITY:+-F "priority=${PRIORITY}"}
  echo "Notification sent successfully"
  exit 0
fi

## Build JSON extras
GENERATED_EXTRAS=$(jq -n '{}')

if [[ -n "$CONTENT_TYPE" ]]; then
  GENERATED_EXTRAS=$(jq -n \
    --arg ct "$CONTENT_TYPE" \
    '{ "client::display": { "contentType": $ct } }')
fi

if [[ -n "$CLICK_URL" ]]; then
  GENERATED_EXTRAS=$(
    echo "$GENERATED_EXTRAS" | jq \
      --arg url "$CLICK_URL" \
      '. + { "client::notification": { "click": { "url": $url } } }'
  )
fi

if [[ -n "$BIG_IMAGE_URL" ]]; then
  GENERATED_EXTRAS=$(
    echo "$GENERATED_EXTRAS" | jq \
      --arg url "$BIG_IMAGE_URL" \
      '. + { "client::notification": { "bigImageUrl": $url } }'
  )
fi

if [[ -n "$INTENT_URL" ]]; then
  GENERATED_EXTRAS=$(
    echo "$GENERATED_EXTRAS" | jq \
      --arg url "$INTENT_URL" \
      '. + { "android::action": { "onReceive": { "intentUrl": $url } } }'
  )
fi

## Merge extras safely
FINAL_EXTRAS=$(
  jq -s 'reduce .[] as $i ({}; . * $i)' \
    <(echo "$GENERATED_EXTRAS") \
    <(echo "$USER_EXTRAS")
)

## Build payload
if [[ -n "$RAW_JSON_PAYLOAD" ]]; then
  PAYLOAD="$RAW_JSON_PAYLOAD"
  log "Using raw payload override"
else
  PAYLOAD=$(
    jq -n \
      --arg message "$MESSAGE" \
      --arg title "$TITLE" \
      --argjson priority "$PRIORITY" \
      --argjson extras "$FINAL_EXTRAS" \
      '
      { message: $message }
      + (if $title != "" then { title: $title } else {} end)
      + (if $priority > 0 then { priority: $priority } else {} end)
      + (if $extras != {} then { extras: $extras } else {} end)
      '
  )
fi

## Validate final payload
echo "$PAYLOAD" | jq .

log "Sending JSON notification"

## Send request
curl "${CURL_FLAGS[@]}" \
  "${GOTIFY_URL}/message?token=${TOKEN}" \
  -H "Content-Type: application/json" \
  "${UA_HEADER[@]}" \
  -d "$PAYLOAD"

echo "Notification sent successfully"
