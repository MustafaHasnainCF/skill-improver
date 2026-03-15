#!/bin/bash

# Skill Improver Stop Hook
# Prevents session exit when a skill improvement loop is active
# Feeds the fixed loop prompt back as input to continue iterating
# Adapted from Ralph Loop's stop-hook.sh with convergence-based exit criteria

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if skill-improver is active
STATE_FILE=".claude/skill-improver.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
BEST_SCORE=$(echo "$FRONTMATTER" | grep '^best_score:' | sed 's/best_score: *//')
TARGET_SCORE=$(echo "$FRONTMATTER" | grep '^target_score:' | sed 's/target_score: *//')
PLATEAU_COUNT=$(echo "$FRONTMATTER" | grep '^plateau_count:' | sed 's/plateau_count: *//')
MAX_PLATEAU=$(echo "$FRONTMATTER" | grep '^max_plateau:' | sed 's/max_plateau: *//')
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')

# If explicitly deactivated (e.g., by /stop-improving), allow exit
if [[ "$ACTIVE" == "false" ]]; then
  exit 0
fi

# Session isolation: only block the session that started the loop
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields before arithmetic operations
for FIELD_NAME in iteration max_iterations plateau_count max_plateau; do
  FIELD_VAL=$(echo "$FRONTMATTER" | grep "^${FIELD_NAME}:" | sed "s/${FIELD_NAME}: *//")
  if [[ ! "$FIELD_VAL" =~ ^[0-9]+$ ]]; then
    echo "Warning: Skill improver state file corrupted (${FIELD_NAME}='${FIELD_VAL}')" >&2
    echo "   Stopping improvement loop. Run /improve-skill again to start fresh." >&2
    rm "$STATE_FILE"
    exit 0
  fi
done

# === Convergence Check 1: Max iterations ===
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Skill improver: Max iterations ($MAX_ITERATIONS) reached. Best score: $BEST_SCORE"
  rm "$STATE_FILE"
  exit 0
fi

# === Convergence Check 2: Target score achieved ===
TARGET_MET=$(python3 -c "print(1 if float('$BEST_SCORE') >= float('$TARGET_SCORE') else 0)" 2>/dev/null || echo "0")
if [[ "$TARGET_MET" == "1" ]]; then
  echo "Skill improver: Target score ($TARGET_SCORE) achieved! Best score: $BEST_SCORE"
  rm "$STATE_FILE"
  exit 0
fi

# === Convergence Check 3: Plateau detected ===
if [[ $PLATEAU_COUNT -ge $MAX_PLATEAU ]]; then
  echo "Skill improver: Plateau detected ($PLATEAU_COUNT consecutive non-improvements). Best score: $BEST_SCORE"
  rm "$STATE_FILE"
  exit 0
fi

# Not converged - continue loop with the fixed prompt
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
# Skip first --- line, skip until second --- line, then print everything after
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "Warning: Skill improver state file has no prompt text" >&2
  echo "   Stopping improvement loop. Run /improve-skill again to start fresh." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (atomic via temp file)
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build system message with iteration count and convergence info
SYSTEM_MSG="Skill Improver iteration $NEXT_ITERATION/$MAX_ITERATIONS | Best: $BEST_SCORE | Target: $TARGET_SCORE | Plateau: $PLATEAU_COUNT/$MAX_PLATEAU"

# Output JSON to block the stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
