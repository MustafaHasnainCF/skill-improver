---
description: >
  Start autonomous skill improvement loop. Analyzes failures, rewrites SKILL.md,
  evaluates, and ratchets improvements until convergence.
argument-hint: "<skill-path> [--max-iterations 20] [--target-score 0.90] [--max-plateau 5] [--strategist-interval 3] [--weights 'assertion:0.5,trigger:0.2,quality:0.3']"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

# Improve Skill

Run the setup script to initialize the improvement loop:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-improvement.sh" $ARGUMENTS
```

After setup completes successfully, read the state file to begin the first iteration:

```bash
cat .claude/skill-improver.local.md
```

Then follow the loop prompt in the state file body. Execute each phase (Analyze, Strategize, Experiment, Evaluate, Ratchet) for this iteration. When you're done with all 5 phases, report the iteration results and exit. The stop hook will catch the exit, update the iteration counter, and feed the prompt back to you for the next iteration.

**Important**: Do not try to run multiple iterations yourself. Complete ONE iteration, then exit. The stop hook handles continuation.
