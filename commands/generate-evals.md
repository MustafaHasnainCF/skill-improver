---
description: >
  Generate evaluation criteria from qualitative objectives. Interviews you
  about what you want to improve, then creates measurable evals.json.
argument-hint: "<skill-path> [--objective 'qualitative description']"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# Generate Evals

Parse the arguments to extract `skill_path` and optional `--objective` flag.

## Step 1: Validate the skill path

```bash
if [[ ! -f "$SKILL_PATH/SKILL.md" ]]; then
  echo "Error: No SKILL.md found at the provided path"
  exit 1
fi
```

Read the skill path from `$ARGUMENTS`. The first argument is the skill path, and if `--objective` is present, everything after it is the objective text.

## Step 2: Determine mode

- If `--objective` was provided: mode is `autonomous`, extract the objective text
- If no `--objective`: mode is `interactive`

## Step 3: Check for existing evals

Read `{skill_path}/evals/evals.json` if it exists. If it already has valid evals with assertions:
- In interactive mode: Ask the user if they want to overwrite or augment existing evals
- In autonomous mode: Overwrite existing evals

## Step 4: Spawn the objective-translator agent

Spawn the `objective-translator` agent (`${CLAUDE_PLUGIN_ROOT}/agents/objective-translator.md`) with:

```
Skill path: {skill_path}
Plugin root: {CLAUDE_PLUGIN_ROOT}
Mode: {interactive|autonomous}
Objective: {objective text, if autonomous mode}
```

The agent will:
- Read and understand the skill
- Interview the user (interactive) or parse the objective (autonomous)
- Generate evals.json with measurable assertions
- Write it to `{skill_path}/evals/evals.json`

## Step 5: Report results

After the agent completes, confirm the evals were written:

```bash
cat {skill_path}/evals/evals.json | python3 -c "
import json, sys
evals = json.load(sys.stdin)
n_evals = len(evals)
n_assertions = sum(len(e.get('assertions', e.get('expectations', []))) for e in evals)
print(f'Generated {n_evals} evals with {n_assertions} total assertions')
"
```

Report success and suggest next steps:
- "Run `/improve-skill {skill_path}` to start the improvement loop with these evals"
