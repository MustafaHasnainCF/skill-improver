#!/bin/bash

# Skill Improver Setup Script
# Creates state file and workspace for autonomous skill improvement loop
# Adapted from Ralph Loop's setup-ralph-loop.sh

set -euo pipefail

# Parse arguments
SKILL_PATH=""
MAX_ITERATIONS=20
TARGET_SCORE="0.90"
MAX_PLATEAU=5
STRATEGIST_INTERVAL=3
SCORE_WEIGHTS="assertion:0.5,trigger:0.2,quality:0.3"

show_help() {
  cat << 'HELP_EOF'
Skill Improver - Autonomous skill improvement via autoresearch loop

USAGE:
  /improve-skill <SKILL_PATH> [OPTIONS]

ARGUMENTS:
  SKILL_PATH    Path to the skill directory (must contain SKILL.md and evals/)

OPTIONS:
  --max-iterations <n>          Maximum iterations before auto-stop (default: 20)
  --target-score <0.0-1.0>      Target composite score to achieve (default: 0.90)
  --max-plateau <n>             Stop after N consecutive non-improvements (default: 5)
  --strategist-interval <n>     Run strategist every N iterations (default: 3)
  --weights <spec>              Score weights as key:value pairs (default: assertion:0.5,trigger:0.2,quality:0.3)
  -h, --help                    Show this help message

EXAMPLES:
  /improve-skill /path/to/my-skill
  /improve-skill /path/to/my-skill --max-iterations 50 --target-score 0.95
  /improve-skill /path/to/my-skill --max-plateau 3 --weights "assertion:0.6,quality:0.4"

STOPPING:
  - Automatically stops when target score is reached
  - Automatically stops after max-plateau consecutive non-improvements
  - Automatically stops at max-iterations
  - Manually stop with /stop-improving
HELP_EOF
  exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer, got: '${2:-}'" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --target-score)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --target-score requires a float value (0.0-1.0)" >&2
        exit 1
      fi
      TARGET_SCORE="$2"
      shift 2
      ;;
    --max-plateau)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-plateau requires a positive integer, got: '${2:-}'" >&2
        exit 1
      fi
      MAX_PLATEAU="$2"
      shift 2
      ;;
    --strategist-interval)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --strategist-interval requires a positive integer, got: '${2:-}'" >&2
        exit 1
      fi
      STRATEGIST_INTERVAL="$2"
      shift 2
      ;;
    --weights)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --weights requires a spec like 'assertion:0.5,trigger:0.2,quality:0.3'" >&2
        exit 1
      fi
      SCORE_WEIGHTS="$2"
      shift 2
      ;;
    *)
      if [[ -z "$SKILL_PATH" ]]; then
        SKILL_PATH="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        echo "  Run with --help for usage information" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate skill path
if [[ -z "$SKILL_PATH" ]]; then
  echo "Error: No skill path provided" >&2
  echo "" >&2
  echo "  Usage: /improve-skill <SKILL_PATH> [OPTIONS]" >&2
  echo "  Run with --help for full usage information" >&2
  exit 1
fi

# Resolve to absolute path
SKILL_PATH=$(cd "$SKILL_PATH" 2>/dev/null && pwd || echo "$SKILL_PATH")

# Convert MSYS/Cygwin paths to Windows paths for Python compatibility
to_python_path() {
  if command -v cygpath &>/dev/null; then
    cygpath -w "$1" 2>/dev/null || echo "$1"
  else
    echo "$1"
  fi
}

if [[ ! -f "$SKILL_PATH/SKILL.md" ]]; then
  echo "Error: No SKILL.md found at $SKILL_PATH" >&2
  echo "  The skill path must contain a SKILL.md file" >&2
  exit 1
fi

# Check for evals
EVALS_PATH=""
if [[ -f "$SKILL_PATH/evals/evals.json" ]]; then
  EVALS_PATH="$SKILL_PATH/evals/evals.json"
elif [[ -f "$SKILL_PATH/evals.json" ]]; then
  EVALS_PATH="$SKILL_PATH/evals.json"
else
  echo "Error: No evals found at $SKILL_PATH/evals/evals.json or $SKILL_PATH/evals.json" >&2
  echo "  The skill must have evaluation definitions to improve against" >&2
  exit 1
fi

# Validate evals.json has assertions
EVALS_PATH_PY=$(to_python_path "$EVALS_PATH")
EVAL_COUNT=$(python3 -c "
import json, sys
try:
    evals = json.load(open(r'$EVALS_PATH_PY'))
    if not isinstance(evals, list) or len(evals) == 0:
        print(0)
    else:
        has_assertions = any('assertions' in e or 'expectations' in e for e in evals)
        print(len(evals) if has_assertions else 0)
except:
    print(0)
" 2>/dev/null || echo "0")

if [[ "$EVAL_COUNT" == "0" ]]; then
  echo "Error: evals.json must be a non-empty array with assertions/expectations" >&2
  echo "  File: $EVALS_PATH" >&2
  exit 1
fi

# Auto-discover skill-creator path
SKILL_CREATOR_PATH=""
for dir in ~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator; do
  if [[ -d "$dir" ]] && [[ -f "$dir/SKILL.md" ]]; then
    SKILL_CREATOR_PATH="$dir"
  fi
done

if [[ -z "$SKILL_CREATOR_PATH" ]]; then
  echo "Error: Could not find skill-creator plugin" >&2
  echo "  Expected at ~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator" >&2
  echo "  Please ensure the skill-creator plugin is installed" >&2
  exit 1
fi

# Create workspace
WORKSPACE_PATH="${SKILL_PATH}-improver-workspace"
mkdir -p "$WORKSPACE_PATH"

# Get skill name from SKILL.md frontmatter
SKILL_PATH_PY=$(to_python_path "$SKILL_PATH")
SKILL_CREATOR_PATH_PY=$(to_python_path "$SKILL_CREATOR_PATH")
SKILL_NAME=$(python3 -c "
import sys
sys.path.insert(0, r'$SKILL_CREATOR_PATH_PY')
from scripts.utils import parse_skill_md
from pathlib import Path
name, desc, content = parse_skill_md(Path(r'$SKILL_PATH_PY'))
print(name)
" 2>/dev/null || basename "$SKILL_PATH")

# Initialize score-history.json
SCORE_HISTORY="$WORKSPACE_PATH/score-history.json"
if [[ ! -f "$SCORE_HISTORY" ]]; then
  cat > "$SCORE_HISTORY" << HIST_EOF
{
  "skill_name": "$SKILL_NAME",
  "skill_path": "$SKILL_PATH",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "best_iteration": 0,
  "best_score": 0.0,
  "iterations": []
}
HIST_EOF
fi

# Check for trigger-evals.json (optional)
TRIGGER_EVALS_PATH=""
if [[ -f "$SKILL_PATH/evals/trigger-evals.json" ]]; then
  TRIGGER_EVALS_PATH="$SKILL_PATH/evals/trigger-evals.json"
elif [[ -f "$SKILL_PATH/trigger-evals.json" ]]; then
  TRIGGER_EVALS_PATH="$SKILL_PATH/trigger-evals.json"
fi

# Determine CLAUDE_PLUGIN_ROOT for compute-score.py path
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Create state file
mkdir -p .claude
cat > .claude/skill-improver.local.md << STATE_EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
target_score: $TARGET_SCORE
max_plateau: $MAX_PLATEAU
plateau_count: 0
best_score: 0.0
current_score: 0.0
skill_path: $SKILL_PATH
workspace_path: $WORKSPACE_PATH
evals_path: $EVALS_PATH
trigger_evals_path: $TRIGGER_EVALS_PATH
skill_creator_path: $SKILL_CREATOR_PATH
strategist_interval: $STRATEGIST_INTERVAL
score_weights: "$SCORE_WEIGHTS"
plugin_root: $PLUGIN_ROOT
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

You are running the Skill Improver autonomous loop. Check the system message for current iteration number and scores.

## Your Task

Improve the skill at \`$SKILL_PATH\` by iterating through: analyze, strategize, experiment, evaluate, ratchet.

## Phase 1 - ANALYZE

Read the previous iteration's results to understand what happened:

1. Read \`$WORKSPACE_PATH/score-history.json\` for the full score trajectory
2. If iteration > 1, read the grading.json files from the previous iteration directory at \`$WORKSPACE_PATH/iteration-{N-1}/\`
3. Identify failure patterns: which assertions failed? What categories of failure? (instruction ambiguity, missing examples, tool misuse, edge cases, output format)
4. Read the current SKILL.md at \`$SKILL_PATH/SKILL.md\`

## Phase 2 - STRATEGIZE

Every $STRATEGIST_INTERVAL iterations, run the strategist agent for meta-analysis:

1. Check if \`iteration % $STRATEGIST_INTERVAL == 0\`
2. If yes, spawn the strategist agent (\`$PLUGIN_ROOT/agents/strategist.md\`) with:
   - Full score history from score-history.json
   - Current SKILL.md content
   - Recent hypotheses from score-history.json iterations
3. Read the strategist's output and factor recommendations into the experiment phase
4. If strategist recommends paradigm_shift, make structural changes instead of tweaks

## Phase 3 - EXPERIMENT

Run the experimenter agent to generate an improved SKILL.md:

1. Spawn the experimenter agent (\`$PLUGIN_ROOT/agents/experimenter.md\`) with:
   - Current SKILL.md content
   - Failure analysis from Phase 1
   - Score history
   - Strategist recommendations (if available from Phase 2)
2. The experimenter will rewrite SKILL.md with a specific hypothesis
3. Save the hypothesis description for score-history.json

## Phase 4 - EVALUATE

Run the evaluator agent to score the modified skill:

1. Create iteration directory: \`$WORKSPACE_PATH/iteration-{N}/\`
2. Spawn the evaluator agent (\`$PLUGIN_ROOT/agents/evaluator.md\`) with:
   - Skill path: \`$SKILL_PATH\`
   - Evals path: \`$EVALS_PATH\`
   - Trigger evals path: \`$TRIGGER_EVALS_PATH\` (if exists)
   - Iteration directory: \`$WORKSPACE_PATH/iteration-{N}/\`
   - Skill creator path: \`$SKILL_CREATOR_PATH\`
   - Score weights: \`$SCORE_WEIGHTS\`
   - Plugin root: \`$PLUGIN_ROOT\`
3. Read the composite score and component scores from the evaluator's output

## Phase 5 - RATCHET

Compare the new score against the best score and decide whether to keep or discard:

1. Read the composite score from Phase 4
2. If composite_score > best_score:
   - Run: \`cd $SKILL_PATH && git add SKILL.md && git commit -m "skill-improver: iteration {N} - score {score} ({hypothesis})"\`
   - Update best_score and reset plateau_count to 0 in the state file
   - Update best_iteration in score-history.json
3. If composite_score <= best_score:
   - Run: \`cd $SKILL_PATH && git checkout -- SKILL.md\` to restore the best version
   - Increment plateau_count in the state file
4. Update score-history.json with this iteration's data:
   \`\`\`json
   {
     "iteration": N,
     "composite_score": X.XX,
     "assertion_score": X.XX,
     "trigger_score": X.XX,
     "quality_score": X.XX,
     "hypothesis": "description of what was changed",
     "kept": true/false,
     "timestamp": "ISO-8601"
   }
   \`\`\`
5. Update the state file frontmatter: current_score, best_score, plateau_count

## Important Rules

- Always read the state file at the start to get current iteration and scores
- Always update the state file at the end with new values
- Use git for version control - commit improvements, checkout regressions
- The stop hook will check convergence and either continue or stop the loop
- Do NOT try to exit early - the stop hook handles convergence detection
- Report your progress clearly at the end of each iteration
STATE_EOF

# Output activation message
cat << ACTIVATE_EOF
Skill Improver activated!

Skill: $SKILL_NAME
Path: $SKILL_PATH
Evals: $EVALS_PATH ($EVAL_COUNT evals)
Trigger evals: $(if [[ -n "$TRIGGER_EVALS_PATH" ]]; then echo "$TRIGGER_EVALS_PATH"; else echo "none"; fi)
Skill creator: $SKILL_CREATOR_PATH
Workspace: $WORKSPACE_PATH

Configuration:
  Max iterations:       $MAX_ITERATIONS
  Target score:         $TARGET_SCORE
  Max plateau:          $MAX_PLATEAU
  Strategist interval:  every $STRATEGIST_INTERVAL iterations
  Score weights:        $SCORE_WEIGHTS

The stop hook is now active. Each iteration will:
  1. Analyze previous results
  2. Strategize (every $STRATEGIST_INTERVAL iterations)
  3. Experiment with SKILL.md changes
  4. Evaluate via evals + grading
  5. Ratchet: keep improvements, discard regressions

Beginning iteration 1...
ACTIVATE_EOF
