#!/usr/bin/env bash
set -Eeuo pipefail

########################################################
# ntfy Notification Script                             #
#                                                      #
# Sends notifications to an ntfy server using HTTP,    #
# supporting simple messages, titles, priorities,      #
# tags, click URLs, actions, attachments, and auth.    #
########################################################

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed." >&2
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
ntfy Notification CLI

USAGE:
  send-ntfy-notification.sh [OPTIONS]

REQUIRED (or via env):
  -s, --ntfy-server     ntfy base URL (or env NTFY_SERVER)
  -T, --topic           ntfy topic name (or env NTFY_TOPIC)
  -m, --message         Notification message (unless --raw-body is used)

OPTIONAL (or via env):
  --title               Notification title
  --priority            Priority (1-5, or min|low|default|high|max)
  --tags                Comma-separated tags (e.g. "ci,build,success")
  --click               Click URL
  --actions             Actions header (X-Actions)
  --attach              Attachment URL or descriptor for X-Attach
  --raw-body            Override message body (raw HTTP body)
  --user-agent          HTTP User-Agent (default: redjax/PipelineTemplates)
  --auth-token          Bearer token for Authorization header
  --username            Basic auth username
  --password            Basic auth password
  --debug               Enable debug logs
  -h, --help            Show help

ENV FALLBACKS:
  NTFY_SERVER
  NTFY_TOPIC
  NTFY_MESSAGE
  NTFY_TITLE
  NTFY_PRIORITY
  NTFY_TAGS
  NTFY_CLICK
  NTFY_ACTIONS
  NTFY_ATTACH
  NTFY_RAW_BODY
  NTFY_USER_AGENT
  NTFY_AUTH_TOKEN
  NTFY_USERNAME
  NTFY_PASSWORD
  DEBUG
EOF
}

NTFY_SERVER="${NTFY_SERVER:-}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
MESSAGE="${NTFY_MESSAGE:-}"
TITLE="${NTFY_TITLE:-}"
PRIORITY="${NTFY_PRIORITY:-}"
TAGS="${NTFY_TAGS:-}"
CLICK="${NTFY_CLICK:-}"
ACTIONS="${NTFY_ACTIONS:-}"
ATTACH="${NTFY_ATTACH:-}"
RAW_BODY="${NTFY_RAW_BODY:-}"
USER_AGENT="${NTFY_USER_AGENT:-redjax/PipelineTemplates}"
AUTH_TOKEN="${NTFY_AUTH_TOKEN:-}"
USERNAME="${NTFY_USERNAME:-}"
PASSWORD="${NTFY_PASSWORD:-}"
DEBUG="${DEBUG:-false}"

UA_HEADER=(-H "User-Agent: ${USER_AGENT}")

while [[ $# -gt 0 ]]; do
  case "$1" in
  -s | --ntfy-server)
    NTFY_SERVER="$2"
    shift 2
    ;;
  -T | --topic)
    NTFY_TOPIC="$2"
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
  --tags)
    TAGS="$2"
    shift 2
    ;;
  --click)
    CLICK="$2"
    shift 2
    ;;
  --actions)
    ACTIONS="$2"
    shift 2
    ;;
  --attach)
    ATTACH="$2"
    shift 2
    ;;
  --raw-body)
    RAW_BODY="$2"
    shift 2
    ;;
  --user-agent)
    USER_AGENT="$2"
    UA_HEADER=(-H "User-Agent: ${USER_AGENT}")
    shift 2
    ;;
  --auth-token)
    AUTH_TOKEN="$2"
    shift 2
    ;;
  --username)
    USERNAME="$2"
    shift 2
    ;;
  --password)
    PASSWORD="$2"
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

NTFY_SERVER="$(trim_ws "$NTFY_SERVER")"
NTFY_TOPIC="$(trim_ws "$NTFY_TOPIC")"
MESSAGE="$(trim_ws "$MESSAGE")"
RAW_BODY="$(trim_ws "$RAW_BODY")"

## Validate required inputs
[[ -n "$NTFY_SERVER" ]] || {
  echo "ERROR: NTFY_SERVER required" >&2
  exit 1
}

[[ -n "$NTFY_TOPIC" ]] || {
  echo "ERROR: NTFY_TOPIC required" >&2
  exit 1
}

if [[ -z "$RAW_BODY" && -z "$MESSAGE" ]]; then
  echo "ERROR: MESSAGE required unless RAW_BODY is provided" >&2
  exit 1
fi

## Build curl flags
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

## Build headers
HEADERS=("${UA_HEADER[@]}")

if [[ -n "$TITLE" ]]; then
  HEADERS+=(-H "X-Title: ${TITLE}")
fi

if [[ -n "$PRIORITY" ]]; then
  HEADERS+=(-H "X-Priority: ${PRIORITY}")
fi

if [[ -n "$TAGS" ]]; then
  HEADERS+=(-H "X-Tags: ${TAGS}")
fi

if [[ -n "$CLICK" ]]; then
  HEADERS+=(-H "X-Click: ${CLICK}")
fi

if [[ -n "$ACTIONS" ]]; then
  HEADERS+=(-H "X-Actions: ${ACTIONS}")
fi

if [[ -n "$ATTACH" ]]; then
  HEADERS+=(-H "X-Attach: ${ATTACH}")
fi

if [[ -n "$AUTH_TOKEN" ]]; then
  HEADERS+=(-H "Authorization: Bearer ${AUTH_TOKEN}")
fi

AUTH_FLAGS=()
if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
  AUTH_FLAGS=(-u "${USERNAME}:${PASSWORD}")
fi

BODY="$MESSAGE"
if [[ -n "$RAW_BODY" ]]; then
  BODY="$RAW_BODY"
  debug "Using raw body override"
fi

TARGET_URL="${NTFY_SERVER%/}/${NTFY_TOPIC}"

debug "Target URL: ${TARGET_URL}"
debug "Title: ${TITLE}"
debug "Priority: ${PRIORITY}"
debug "Tags: ${TAGS}"
debug "Click: ${CLICK}"
debug "Actions: ${ACTIONS}"
debug "Attach: ${ATTACH}"

log "Sending ntfy notification"

curl "${CURL_FLAGS[@]}" \
  "${HEADERS[@]}" \
  "${AUTH_FLAGS[@]}" \
  -d "$BODY" \
  "$TARGET_URL"

echo "Notification sent successfully"
