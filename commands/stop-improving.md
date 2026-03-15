---
description: Stop the active skill improvement loop and report final results
allowed-tools:
  - Bash
  - Read
---

# Stop Improving

Check if there's an active improvement loop and stop it:

```bash
if [ -f .claude/skill-improver.local.md ]; then
  echo "Active improvement loop found"
else
  echo "No active improvement loop"
fi
```

If active, read the state file to report status:

```bash
cat .claude/skill-improver.local.md
```

Then read score history for the final report:

```bash
# Extract workspace_path from frontmatter
WORKSPACE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' .claude/skill-improver.local.md | grep '^workspace_path:' | sed 's/workspace_path: *//')
if [ -f "$WORKSPACE/score-history.json" ]; then
  cat "$WORKSPACE/score-history.json"
fi
```

Report the results to the user:
- Total iterations completed
- Best score achieved and which iteration
- Score trajectory summary
- Whether target was reached

Then deactivate by removing the state file:

```bash
rm .claude/skill-improver.local.md
echo "Improvement loop stopped."
```
