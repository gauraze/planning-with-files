#!/usr/bin/env bash
# check-complete.sh
# Checks whether all tasks in a plan file are marked as complete.
# Usage: ./check-complete.sh <plan-file>
# Exit codes:
#   0 - All tasks complete
#   1 - One or more tasks incomplete
#   2 - Invalid arguments or file not found

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 <plan-file>" >&2
    echo "" >&2
    echo "  <plan-file>  Path to the markdown plan file to check." >&2
    exit 2
}

error() {
    echo "[ERROR] $*" >&2
}

info() {
    echo "[INFO]  $*"
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [[ $# -ne 1 ]]; then
    usage
fi

PLAN_FILE="$1"

if [[ ! -f "$PLAN_FILE" ]]; then
    error "Plan file not found: $PLAN_FILE"
    exit 2
fi

# ---------------------------------------------------------------------------
# Parse the plan file
# Markdown task syntax:
#   incomplete: - [ ] Task description
#   complete:   - [x] Task description  (case-insensitive x)
# ---------------------------------------------------------------------------
TOTAL_TASKS=0
INCOMPLETE_TASKS=0
COMPLETE_TASKS=0

while IFS= read -r line; do
    # Match any checkbox task item
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[([[:space:]xX])\] ]]; then
        TOTAL_TASKS=$(( TOTAL_TASKS + 1 ))
        marker="${BASH_REMATCH[1]}"
        if [[ "$marker" =~ ^[xX]$ ]]; then
            COMPLETE_TASKS=$(( COMPLETE_TASKS + 1 ))
        else
            INCOMPLETE_TASKS=$(( INCOMPLETE_TASKS + 1 ))
            # Print the incomplete task for visibility
            trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
            echo "  INCOMPLETE: $trimmed"
        fi
    fi
done < "$PLAN_FILE"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo ""
info "Plan file  : $PLAN_FILE"
info "Total tasks: $TOTAL_TASKS"
info "Complete   : $COMPLETE_TASKS"
info "Incomplete : $INCOMPLETE_TASKS"
echo ""

if [[ $TOTAL_TASKS -eq 0 ]]; then
    error "No tasks found in plan file. Verify the file contains checkbox items (- [ ] or - [x])."
    exit 2
fi

if [[ $INCOMPLETE_TASKS -eq 0 ]]; then
    info "✅ All $TOTAL_TASKS task(s) are complete."
    exit 0
else
    error "❌ $INCOMPLETE_TASKS of $TOTAL_TASKS task(s) are still incomplete."
    exit 1
fi
