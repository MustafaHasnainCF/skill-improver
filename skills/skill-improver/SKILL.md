---
name: skill-improver
description: >
  Autonomously improve, optimize, and iterate on Claude Code skills using an autoresearch-inspired loop.
  Use when the user wants to "improve a skill", "optimize a skill", "make a skill better automatically",
  "autoresearch this skill", "run improvement loop on skill", "iterate on skill quality",
  "auto-improve skill evals", or "overnight skill optimization".
---

# Skill Improver

Autonomous skill improvement engine that combines autoresearch-style experimentation with skill-creator's evaluation infrastructure.

## What This Does

Takes a skill with evals, then autonomously loops through:
1. **Analyze** — Identify failure patterns from previous iteration
2. **Strategize** — Periodic meta-analysis of score trajectory (every N iterations)
3. **Experiment** — Rewrite SKILL.md based on evidence-driven hypotheses
4. **Evaluate** — Run evals, grade outputs, compute composite score
5. **Ratchet** — Keep improvements (git commit), discard regressions (git checkout)

The loop continues until target score is reached, a plateau is detected, or max iterations are hit.

## How to Use

Tell the user to run:
```
/improve-skill <path-to-skill> [--max-iterations 20] [--target-score 0.90] [--max-plateau 5]
```

Or if the user describes wanting to improve a skill, invoke the `/improve-skill` command for them with the appropriate arguments.

## Architecture

- **Stop Hook**: Prevents session exit, feeds the loop prompt back each iteration
- **Experimenter Agent**: Analyzes failures, generates hypotheses, rewrites SKILL.md
- **Evaluator Agent**: Runs evals using skill-creator infrastructure, computes composite score
- **Strategist Agent**: Meta-analyzes score trajectory every N iterations, recommends direction changes
- **Ratchet Mechanism**: Git-based — only commits improvements, reverts regressions
- **Convergence Detection**: Target score, plateau detection, max iterations

## Requirements

- The skill must have a `SKILL.md` file
- The skill must have `evals/evals.json` (or `evals.json`) with assertions
- The skill-creator plugin must be installed
- Git must be initialized in the skill's directory
