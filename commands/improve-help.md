---
description: Explain the skill-improver plugin architecture and usage
---

# Skill Improver Help

Explain the following to the user:

## Overview

The **skill-improver** plugin autonomously improves Claude Code skills through an autoresearch-inspired experimentation loop. It combines:

- **Karpathy's autoresearch pattern**: modify -> evaluate -> keep/discard -> repeat
- **Skill-creator's eval infrastructure**: grader agent, benchmark aggregation, assertions
- **Ralph Loop's stop hook**: in-session looping with session isolation

## Commands

| Command | Description |
|---------|-------------|
| `/improve-skill <path> [options]` | Start the improvement loop |
| `/stop-improving` | Cancel the active loop and show results |
| `/improve-help` | Show this help |

## Options for /improve-skill

| Option | Default | Description |
|--------|---------|-------------|
| `--max-iterations` | 20 | Maximum iterations before auto-stop |
| `--target-score` | 0.90 | Target composite score (0.0-1.0) |
| `--max-plateau` | 5 | Stop after N consecutive non-improvements |
| `--strategist-interval` | 3 | Run strategist every N iterations |
| `--weights` | assertion:0.5,trigger:0.2,quality:0.3 | Component score weights |

## How It Works

Each iteration runs 5 phases:

1. **Analyze** — Read previous grading results, identify failure patterns
2. **Strategize** — Every N iterations, meta-analyze the score trajectory
3. **Experiment** — Rewrite SKILL.md based on evidence-driven hypotheses
4. **Evaluate** — Run evals, grade outputs, compute composite score
5. **Ratchet** — Git commit improvements, git checkout regressions

The loop stops when:
- Target score is reached
- Plateau detected (N consecutive non-improvements)
- Max iterations exhausted

## Requirements

- Skill must have `SKILL.md` and `evals/evals.json` with assertions
- `skill-creator` plugin must be installed
- Git must be initialized in the skill's directory

## Scoring

Composite score = weighted sum of:
- **Assertion score** (50%): Do outputs pass the defined assertions?
- **Trigger score** (20%): Does the skill description trigger correctly? (optional)
- **Quality score** (30%): Overall grading quality from the grader agent

## Monitoring

While running, check progress:
```bash
# Current iteration and scores
head -20 .claude/skill-improver.local.md

# Full score history
cat <workspace>/score-history.json
```

## Architecture

```
Stop Hook (hooks/stop-hook.sh)
  └─> Checks convergence criteria
  └─> Feeds loop prompt back if not converged

Main Loop (SKILL.md prompt in state file)
  ├─> Experimenter Agent — rewrites SKILL.md
  ├─> Evaluator Agent — runs evals + computes score
  └─> Strategist Agent — periodic meta-analysis

Ratchet (git commit/checkout)
  └─> Only keeps improvements, reverts regressions
```
