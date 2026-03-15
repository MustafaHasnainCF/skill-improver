# skill-improver

A Claude Code plugin that **autonomously improves skills** through an autoresearch-inspired experimentation loop. Point it at any skill with evals, walk away, and come back to a better skill.

## What it does

Skill-improver takes a skill that has evaluation definitions (assertions) and iteratively rewrites it to score higher — like Karpathy's [autoresearch](https://github.com/karpathy/autoresearch) but for Claude Code skills instead of ML experiments.

Each iteration runs 5 phases:

1. **Analyze** — Read previous grading results, identify failure patterns
2. **Strategize** — Every N iterations, a strategist agent meta-analyzes the score trajectory and recommends direction changes
3. **Experiment** — An experimenter agent rewrites SKILL.md based on evidence-driven hypotheses
4. **Evaluate** — An evaluator agent runs evals, grades outputs with skill-creator's grader, and computes a composite score
5. **Ratchet** — If the score improved, git commit the changes. If not, git checkout to restore the best version.

The loop automatically stops when:
- **Target score** is reached (default: 0.90)
- **Plateau detected** — N consecutive iterations without improvement (default: 5)
- **Max iterations** exhausted (default: 20)

## Architecture

```
Stop Hook (hooks/stop-hook.sh)
  └─> Checks convergence criteria (target score, plateau, max iterations)
  └─> Feeds loop prompt back if not converged

Main Loop (state file prompt)
  ├─> Experimenter Agent — analyzes failures, generates hypotheses, rewrites SKILL.md
  ├─> Evaluator Agent — runs evals + grades + computes composite score
  └─> Strategist Agent — periodic meta-analysis, detects plateau/oscillation

Ratchet (git commit/checkout)
  └─> Only keeps improvements, automatically reverts regressions
```

## Scoring

Composite score = weighted combination of:

| Component | Default Weight | What it measures |
|-----------|---------------|------------------|
| **Assertion score** | 50% | Do outputs pass the defined assertions? |
| **Trigger score** | 20% | Does the skill description trigger correctly? (optional) |
| **Quality score** | 30% | Overall grading quality from the grader agent |

If trigger evals don't exist, the weight is redistributed proportionally to assertion and quality.

## Installation

```bash
claude plugins add MustafaHasnainCF/skill-improver
```

Or install from a local directory:

```bash
claude plugins add /path/to/skill-improver
```

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- The **skill-creator** plugin (used for grading and benchmarking)
- `jq` (used by the stop hook)
- `python3` (used for scoring)
- `git` (used for the ratchet mechanism)

## Usage

### Start improving a skill

```
/improve-skill /path/to/my-skill
```

### With options

```
/improve-skill /path/to/my-skill --max-iterations 50 --target-score 0.95 --max-plateau 3
```

### All options

| Option | Default | Description |
|--------|---------|-------------|
| `--max-iterations` | 20 | Maximum iterations before auto-stop |
| `--target-score` | 0.90 | Target composite score (0.0-1.0) |
| `--max-plateau` | 5 | Stop after N consecutive non-improvements |
| `--strategist-interval` | 3 | Run strategist every N iterations |
| `--weights` | `assertion:0.5,trigger:0.2,quality:0.3` | Component score weights |

### Other commands

| Command | Description |
|---------|-------------|
| `/stop-improving` | Cancel the active loop and report final results |
| `/improve-help` | Show usage help |

### Monitor progress

```bash
# Current iteration and scores
head -20 .claude/skill-improver.local.md

# Full score history
cat <workspace>/score-history.json
```

## Requirements for the target skill

- Must have a `SKILL.md` file
- Must have `evals/evals.json` (or `evals.json`) with assertions
- Must be in a git repository

## How it works under the hood

The plugin uses Claude Code's **Stop hook** API (adapted from [Ralph Loop](https://github.com/anthropics/claude-code-plugins)) to create an autonomous loop within a single session. When Claude tries to exit after completing an iteration, the stop hook intercepts, checks convergence criteria, and if not converged, feeds the loop prompt back as a new user message — creating a self-referential improvement cycle.

State is maintained in `.claude/skill-improver.local.md` (a markdown file with YAML frontmatter) and `score-history.json` in the workspace directory. Session isolation ensures the hook only blocks the session that started the loop.

## Plugin structure

```
skill-improver/
├── .claude-plugin/plugin.json     # Plugin manifest
├── skills/skill-improver/SKILL.md # Main skill (triggers on "improve skill" etc.)
├── commands/
│   ├── improve-skill.md           # /improve-skill slash command
│   ├── stop-improving.md          # /stop-improving cancel command
│   └── improve-help.md            # /improve-help usage docs
├── agents/
│   ├── evaluator.md               # Runs evals + computes composite score
│   ├── experimenter.md            # Rewrites SKILL.md based on failure analysis
│   └── strategist.md              # Meta-analyzes score trajectory
├── hooks/
│   ├── hooks.json                 # Stop hook registration
│   └── stop-hook.sh               # Convergence checking + prompt feeding
├── scripts/
│   ├── setup-improvement.sh       # Validates inputs, creates state + workspace
│   └── compute-score.py           # Weighted composite score calculator
└── references/
    ├── scoring.md                 # Scoring algorithm docs
    └── state-schema.md            # State file format docs
```

## License

MIT
