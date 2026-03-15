# State File Schema

Location: `.claude/skill-improver.local.md`

## Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `active` | boolean | Whether the loop is active |
| `iteration` | integer | Current iteration number (1-indexed) |
| `session_id` | string | Session that started the loop (for isolation) |
| `max_iterations` | integer | Maximum iterations before auto-stop |
| `target_score` | float | Target composite score (0.0-1.0) |
| `max_plateau` | integer | Max consecutive non-improvements before stop |
| `plateau_count` | integer | Current consecutive non-improvement count |
| `best_score` | float | Highest composite score achieved |
| `current_score` | float | Most recent iteration's composite score |
| `skill_path` | string | Absolute path to the skill being improved |
| `workspace_path` | string | Absolute path to the improvement workspace |
| `evals_path` | string | Absolute path to evals.json |
| `trigger_evals_path` | string | Path to trigger-evals.json (empty if none) |
| `skill_creator_path` | string | Path to skill-creator plugin |
| `strategist_interval` | integer | Run strategist every N iterations |
| `score_weights` | string | Weight spec (e.g., "assertion:0.5,trigger:0.2,quality:0.3") |
| `plugin_root` | string | Path to skill-improver plugin root |
| `started_at` | string | ISO-8601 timestamp of when the loop started |

## Body Content

Everything after the closing `---` is the fixed loop prompt that gets fed back each iteration by the stop hook.

## Score History Format

Location: `{workspace_path}/score-history.json`

```json
{
  "skill_name": "my-skill",
  "skill_path": "/path/to/skill",
  "started_at": "2026-03-15T10:00:00Z",
  "best_iteration": 3,
  "best_score": 0.78,
  "iterations": [
    {
      "iteration": 1,
      "composite_score": 0.45,
      "assertion_score": 0.50,
      "trigger_score": 0.30,
      "quality_score": 0.50,
      "hypothesis": "Add explicit step-by-step instructions",
      "kept": true,
      "timestamp": "2026-03-15T10:05:00Z"
    }
  ]
}
```
