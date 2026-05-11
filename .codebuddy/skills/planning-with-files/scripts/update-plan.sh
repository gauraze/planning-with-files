#!/usr/bin/env bash
# update-plan.sh — Update a task's status within a plan file
# Usage: ./update-plan.sh <plan-file> <task-id> <new-status>
#
# Supported statuses: todo, in-progress, done, blocked, skipped
#
# Example:
#   ./update-plan.sh plan.md TASK-3 done

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
VALID_STATUSES=("todo" "in-progress" "done" "blocked" "skipped")

# ANSI colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
  echo -e "${CYAN}Usage:${NC} $0 <plan-file> <task-id> <new-status>"
  echo ""
  echo "  plan-file   Path to the markdown plan file"
  echo "  task-id     Task identifier (e.g. TASK-1, #3, or any unique label)"
  echo "  new-status  One of: ${VALID_STATUSES[*]}"
  exit 1
}

die() {
  echo -e "${RED}ERROR:${NC} $1" >&2
  exit 1
}

info() {
  echo -e "${GREEN}INFO:${NC} $1"
}

warn() {
  echo -e "${YELLOW}WARN:${NC} $1"
}

is_valid_status() {
  local s="$1"
  for v in "${VALID_STATUSES[@]}"; do
    [[ "$s" == "$v" ]] && return 0
  done
  return 1
}

# Map a status string to its markdown checkbox / badge representation
status_to_marker() {
  case "$1" in
    todo)        echo "[ ]" ;;
    in-progress) echo "[-]" ;;
    done)        echo "[x]" ;;
    blocked)     echo "[!]" ;;
    skipped)     echo "[~]" ;;
    *)           echo "[ ]" ;;
  esac
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
[[ $# -lt 3 ]] && usage

PLAN_FILE="$1"
TASK_ID="$2"
NEW_STATUS="$3"

[[ -f "$PLAN_FILE" ]] || die "Plan file not found: $PLAN_FILE"

is_valid_status "$NEW_STATUS" || \
  die "Invalid status '${NEW_STATUS}'. Valid options: ${VALID_STATUSES[*]}"

# ---------------------------------------------------------------------------
# Locate the task line
# ---------------------------------------------------------------------------
# We search for a line containing the task ID (case-insensitive).
# The line is expected to contain a checkbox marker such as [ ], [x], [-], etc.
MATCH_LINE=$(grep -n "${TASK_ID}" "$PLAN_FILE" | head -n 1 || true)

if [[ -z "$MATCH_LINE" ]]; then
  die "Task '${TASK_ID}' not found in ${PLAN_FILE}"
fi

LINE_NUM=$(echo "$MATCH_LINE" | cut -d: -f1)
LINE_CONTENT=$(sed -n "${LINE_NUM}p" "$PLAN_FILE")

info "Found task on line ${LINE_NUM}: ${LINE_CONTENT}"

# ---------------------------------------------------------------------------
# Detect current status marker and replace it
# ---------------------------------------------------------------------------
NEW_MARKER=$(status_to_marker "$NEW_STATUS")

# Replace any existing checkbox pattern with the new marker
# Patterns handled: [ ] [x] [X] [-] [!] [~]
UPDATED_LINE=$(echo "$LINE_CONTENT" | sed -E "s/\\[[xX~!\\- ]\\]/${NEW_MARKER}/g")

if [[ "$LINE_CONTENT" == "$UPDATED_LINE" ]]; then
  # No checkbox found — append the marker before the task ID as a prefix
  warn "No existing checkbox found; prepending marker to the task line."
  UPDATED_LINE=$(echo "$LINE_CONTENT" | sed -E "s/(${TASK_ID})/- ${NEW_MARKER} \1/")
fi

# ---------------------------------------------------------------------------
# Write the change back to the file (in-place, portable)
# ---------------------------------------------------------------------------
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

awk -v line_num="$LINE_NUM" -v new_line="$UPDATED_LINE" \
  'NR == line_num { print new_line; next } { print }' \
  "$PLAN_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$PLAN_FILE"

info "Task '${TASK_ID}' updated to status '${NEW_STATUS}' in ${PLAN_FILE}"
