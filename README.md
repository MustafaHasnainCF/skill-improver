# skill-improver

A Claude Code plugin that **autonomously improves skills** through an autoresearch-inspired experimentation loop. Point it at any skill, describe what you want improved in plain English, and come back to a better skill — no manual eval writing required.

## What it does

Skill-improver takes a skill and iteratively rewrites it to score higher — like Karpathy's [autoresearch](https://github.com/karpathy/autoresearch) but for Claude Code skills instead of ML experiments.

You don't need to write evals by hand. The plugin interviews you about your goals, generates measurable evaluation criteria automatically, then runs an autonomous improvement loop against those criteria.

## Quick start

```
/improve-skill /path/to/my-skill
```

That's it. If the skill doesn't have evals yet, the plugin walks you through a short interview to understand what "better" means for your skill, then generates the evals and starts improving.

---

## How evals get created (you don't write them)

When you run `/improve-skill` on a skill that has no `evals/evals.json`, or when you run `/generate-evals` directly, the **objective-translator** agent takes over. It uses a focused interview flow — similar to the brainstorming QA pattern — to extract what you actually care about, then translates your answers into concrete, measurable test cases.

### The interview flow

The translator reads your skill first (SKILL.md, references, scripts, agents) to understand what it does before asking anything. Then it walks through 3-5 targeted questions:

| Step | Question | Format |
|------|----------|--------|
| **Q1** | What's the #1 thing you want improved? | Multiple choice — options tailored to your skill (output quality, edge cases, conciseness, formatting, tool usage, etc.) |
| **Q2** | Drill-down on your primary goal | Multiple choice — adapts based on Q1 (e.g., if "edge cases" → which kinds? empty input, large input, malformed, unicode) |
| **Q3** | Give me an example where the skill currently fails | Open-ended — describe a scenario or paste a prompt |
| **Q4** | What does "good" look like for that example? | Open-ended — what should the output contain or avoid? |
| **Q5** | Anything else to cover? | Multiple choice — add another goal, add edge cases, or "that covers it" |

Each question uses `AskUserQuestion` — one at a time, never combined, with multiple-choice options where possible.

### What it generates

From your answers, the translator creates `evals/evals.json` with:

- **7-10 test prompts** that realistic users would actually type — with context, specific details, and casual language
- **3-5 assertions per prompt** — each verifiable (a grader can check pass/fail from the output), discriminating (fails if the skill doesn't do the right thing), and mapped to your stated objectives
- **Balanced coverage** across happy paths (3-5), edge cases (2-3), error scenarios (1-2), and anti-pattern checks (1-2)

Before writing, it presents the evals for your review: you can approve, adjust specific assertions, add scenarios, or start over.

### Autonomous mode

If you already know what you want, skip the interview:

```
/improve-skill /path/to/my-skill --objective "more concise outputs, better edge case handling"
/generate-evals /path/to/my-skill --objective "should use Edit instead of Write for existing files"
```

The translator parses your objective text directly and generates evals without asking questions.

### Standalone eval generation

You can also generate evals without starting the improvement loop:

```
/generate-evals /path/to/my-skill
```

This runs just the interview and eval generation, then suggests running `/improve-skill` as the next step.

---

## How the improvement loop works

Once evals exist, the plugin runs an autonomous 5-phase loop. Each iteration tries a hypothesis, measures the result, and keeps only what works.

### The 5 phases

```
┌─────────────────────────────────────────────────────────┐
│  PHASE 1: ANALYZE                                       │
│  Read previous grading results, categorize failures     │
│  into: instruction ambiguity, missing examples,         │
│  tool misuse, edge cases, output format, scope creep    │
├─────────────────────────────────────────────────────────┤
│  PHASE 2: STRATEGIZE (every N iterations)               │
│  Strategist agent meta-analyzes the score trajectory    │
│  Detects plateau, oscillation, diminishing returns      │
│  Recommends: continue, paradigm shift, adjust focus     │
├─────────────────────────────────────────────────────────┤
│  PHASE 3: EXPERIMENT                                    │
│  Experimenter agent rewrites SKILL.md                   │
│  Exactly ONE hypothesis per iteration                   │
│  Consults skill audit checklist for sharper diagnosis    │
├─────────────────────────────────────────────────────────┤
│  PHASE 4: EVALUATE                                      │
│  Evaluator agent runs every eval prompt against the     │
│  modified skill, grades outputs with skill-creator's    │
│  grader, computes weighted composite score              │
├─────────────────────────────────────────────────────────┤
│  PHASE 5: RATCHET                                       │
│  Score improved? → git commit the changes               │
│  Score regressed? → git checkout to restore best version│
│  Only improvements survive. Regressions are impossible. │
└─────────────────────────────────────────────────────────┘
        ↓                                       ↑
    Stop hook checks convergence ─── not done ──┘
        ↓ done
    Exit with final results
```

### How it evaluates itself

The evaluation is multi-layered — the plugin doesn't just check "did the assertions pass", it computes a composite score from three independent signals:

**1. Assertion score (default 50% weight)**
Each eval prompt is run against the modified skill. The output is graded against every assertion in `evals.json`. Pass rate across all assertions across all evals = assertion score.

**2. Quality score (default 30% weight)**
The skill-creator grader agent reads the full execution transcript and outputs, then independently assesses overall quality. This catches things assertions miss — like an output that technically passes all checks but feels robotic or misses the point.

**3. Trigger score (default 20% weight, optional)**
If `trigger-evals.json` exists, the plugin tests whether the skill's description correctly triggers on prompts it should handle and doesn't trigger on prompts it shouldn't. This ensures description quality improves alongside skill quality.

**Composite calculation:**
```
composite = (0.50 × assertion) + (0.30 × quality) + (0.20 × trigger)
```

If no trigger evals exist, weights redistribute proportionally (assertion=0.625, quality=0.375).

### The ratchet mechanism

After each evaluation, the ratchet makes a binary decision:

- **Score improved** → `git commit` the SKILL.md changes with the hypothesis as the commit message. Update `best_score`. Reset plateau counter.
- **Score didn't improve** → `git checkout -- SKILL.md` to restore the best-known version. Increment plateau counter.

This means the skill can never get worse. Every committed version is strictly better than the last. Failed experiments are discarded automatically.

### Convergence (when does it stop?)

The stop hook checks three criteria after each iteration:

| Condition | Default | What happens |
|-----------|---------|-------------|
| Target score reached | 0.90 | Loop exits — skill is good enough |
| Plateau detected | 5 consecutive non-improvements | Loop exits — further iteration unlikely to help |
| Max iterations exhausted | 20 | Loop exits — budget spent |

### Strategic meta-analysis

Every N iterations (default: 3), the **strategist agent** analyzes the full score trajectory and recommends one of:

| Recommendation | When | Effect |
|---|---|---|
| `continue` | Score trending up, hypotheses being kept | Keep iterating normally |
| `paradigm_shift` | Plateau with recurring failure categories, or 3+ rewrite signals present | Experimenter makes structural changes instead of incremental tweaks |
| `adjust_focus` | One score component much lower than others | Shift experimenter's attention to the weak component |
| `adjust_weights` | High composite but outputs feel wrong | Rebalance scoring weights |

---

## Scoring

| Component | Default Weight | Source |
|-----------|---------------|--------|
| **Assertion score** | 50% | Pass rate across all eval assertions |
| **Quality score** | 30% | Grader agent's independent quality assessment |
| **Trigger score** | 20% | Description triggering accuracy (optional) |

---

## Installation

```bash
claude plugins install skill-improver
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

### With a pre-defined objective (skip interview)

```
/improve-skill /path/to/my-skill --objective "more concise, handle empty input gracefully"
```

### Generate evals only (no improvement loop)

```
/generate-evals /path/to/my-skill
```

### All options

| Option | Default | Description |
|--------|---------|-------------|
| `--max-iterations` | 20 | Maximum iterations before auto-stop |
| `--target-score` | 0.90 | Target composite score (0.0-1.0) |
| `--max-plateau` | 5 | Stop after N consecutive non-improvements |
| `--strategist-interval` | 3 | Run strategist every N iterations |
| `--weights` | `assertion:0.5,trigger:0.2,quality:0.3` | Component score weights |
| `--objective` | — | Skip interview, use this objective directly |

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
- Must be in a git repository
- Evals are optional — the plugin generates them if missing

## How it works under the hood

The plugin uses Claude Code's **Stop hook** API (adapted from [Ralph Loop](https://github.com/anthropics/claude-code-plugins)) to create an autonomous loop within a single session. When Claude tries to exit after completing an iteration, the stop hook intercepts, checks convergence criteria, and if not converged, feeds the loop prompt back as a new user message — creating a self-referential improvement cycle.

State is maintained in `.claude/skill-improver.local.md` (a markdown file with YAML frontmatter) and `score-history.json` in the workspace directory. Session isolation ensures the hook only blocks the session that started the loop.

## Plugin structure

```
skill-improver/
├── .claude-plugin/plugin.json     # Plugin manifest (v1.2.0)
├── skills/skill-improver/SKILL.md # Main skill (triggers on "improve skill" etc.)
├── commands/
│   ├── improve-skill.md           # /improve-skill slash command
│   ├── generate-evals.md          # /generate-evals slash command
│   ├── stop-improving.md          # /stop-improving cancel command
│   └── improve-help.md            # /improve-help usage docs
├── agents/
│   ├── evaluator.md               # Runs evals + computes composite score
│   ├── experimenter.md            # Rewrites SKILL.md based on failure analysis
│   ├── strategist.md              # Meta-analyzes score trajectory
│   └── objective-translator.md    # Interviews user, generates evals.json
├── hooks/
│   ├── hooks.json                 # Stop hook registration
│   └── stop-hook.sh               # Convergence checking + prompt feeding
├── scripts/
│   ├── setup-improvement.sh       # Validates inputs, creates state + workspace
│   └── compute-score.py           # Weighted composite score calculator
└── references/
    ├── scoring.md                 # Scoring algorithm docs
    ├── state-schema.md            # State file format docs
    ├── objective-patterns.md      # Objective → assertion translation patterns
    └── skill-audit-checklist.md   # 24-item checklist for failure diagnosis
```

## License

MIT
