#!/usr/bin/env bash
set -Eeuo pipefail

########################################################
# Gotify Notification Script                           #
#                                                      #
# Sends notifications to a Gotify server, supporting   #
# simple messages, clickable notifications, images,    #
# raw JSON payload overrides, and JSON extras merge.   #
########################################################

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq is not installed." >&2
  exit 1
fi

## Trim whitespace from input string
function trim_ws() {
  local s="$1"

  s="${s#"${s%%[!$' \t\r\n']*}"}"
  s="${s%"${s##*[!$' \t\r\n']}"}"
  printf '%s' "$s"
}

function log() {
  echo "[INFO] $*"
}

function debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo "[DEBUG] $*"
  fi
}

function usage() {
  cat <<'EOF'
Gotify Notification CLI

USAGE:
  send-notification.sh [OPTIONS]

REQUIRED:
  -m, --message        Notification message (unless --raw-payload is used)

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
  --extras-json        JSON object string (default: {})
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

GOTIFY_URL="${GOTIFY_URL:-}"
TOKEN="${GOTIFY_TOKEN:-}"
TITLE="${TITLE:-}"
MESSAGE="${MESSAGE:-}"
PRIORITY="${PRIORITY:-0}"
USE_JSON="${USE_JSON:-true}"
CONTENT_TYPE="${CONTENT_TYPE:-text/plain}"
CLICK_URL="${CLICK_URL:-}"
BIG_IMAGE_URL="${BIG_IMAGE_URL:-}"
INTENT_URL="${INTENT_URL:-}"
USER_EXTRAS="${USER_EXTRAS:-}"
RAW_JSON_PAYLOAD="${RAW_JSON_PAYLOAD:-}"
USER_AGENT="${USER_AGENT:-redjax/PipelineTemplates}"
DEBUG="${DEBUG:-false}"

UA_HEADER=(-H "User-Agent: ${USER_AGENT}")

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
    UA_HEADER=(-H "User-Agent: ${USER_AGENT}")
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
    echo "Unknown option: $1" >&2
    usage
    exit 1
    ;;
  esac
done

## Validate required inputs
[[ -n "$GOTIFY_URL" ]] || {
  echo "ERROR: GOTIFY_URL required" >&2
  exit 1
}
[[ -n "$TOKEN" ]] || {
  echo "ERROR: GOTIFY_TOKEN required" >&2
  exit 1
}

RAW_JSON_PAYLOAD="$(trim_ws "$RAW_JSON_PAYLOAD")"
USER_EXTRAS="$(trim_ws "$USER_EXTRAS")"

if [[ -z "$RAW_JSON_PAYLOAD" && -z "$MESSAGE" ]]; then
  echo "ERROR: MESSAGE required unless RAW_JSON_PAYLOAD is provided" >&2
  exit 1
fi

## Normalize USER_EXTRAS & RAW_JSON_PAYLOAD
if [[ -z "$USER_EXTRAS" ]]; then
  USER_EXTRAS='{}'
fi

if [[ -n "$RAW_JSON_PAYLOAD" ]]; then
  echo "$RAW_JSON_PAYLOAD" | jq -e . >/dev/null || {
    echo "ERROR: RAW_JSON_PAYLOAD invalid JSON" >&2
    exit 1
  }
fi

echo "$USER_EXTRAS" | jq -e 'type=="object"' >/dev/null || {
  echo "ERROR: USER_EXTRAS must be a JSON object" >&2
  exit 1
}

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

GENERATED_EXTRAS="$(
  jq -n \
    --arg ct "$CONTENT_TYPE" \
    --arg click_url "$CLICK_URL" \
    --arg big_image_url "$BIG_IMAGE_URL" \
    --arg intent_url "$INTENT_URL" \
    '
    {
      "client::display": (
        if $ct != "" then { "contentType": $ct } else {} end
      ),
      "client::notification": (
        {}
        + (if $click_url != "" then { click: { url: $click_url } } else {} end)
        + (if $big_image_url != "" then { bigImageUrl: $big_image_url } else {} end)
      ),
      "android::action": (
        if $intent_url != "" then { onReceive: { intentUrl: $intent_url } } else {} end
      )
    }
    | with_entries(select(.value != {}))
    '
)"

FINAL_EXTRAS="$(jq -s 'reduce .[] as $i ({}; . * $i)' <(printf '%s\n' "$GENERATED_EXTRAS") <(printf '%s\n' "$USER_EXTRAS"))"

if [[ -n "$RAW_JSON_PAYLOAD" ]]; then
  PAYLOAD="$RAW_JSON_PAYLOAD"
  log "Using raw payload override"
else
  PAYLOAD="$(
    jq -n \
      --arg message "$MESSAGE" \
      --arg title "$TITLE" \
      --argjson priority "$PRIORITY" \
      --argjson extras "$FINAL_EXTRAS" \
      '{
        message: $message
      }
      + (if $title != "" then { title: $title } else {} end)
      + (if $priority > 0 then { priority: $priority } else {} end)
      + (if $extras != {} then { extras: $extras } else {} end)'
  )"
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
