# Scoring Algorithm

The skill-improver uses a weighted composite score to evaluate skill quality.

## Component Scores

### Assertion Score (default weight: 0.5)
- Source: `benchmark.json` from `aggregate_benchmark.py`
- Calculation: Mean pass rate across all eval runs
- Range: 0.0 - 1.0
- Measures: Whether the skill produces outputs that satisfy the defined assertions

### Trigger Score (default weight: 0.2)
- Source: `run_eval.py` trigger evaluation results
- Calculation: Proportion of trigger queries that correctly triggered (or didn't trigger) the skill
- Range: 0.0 - 1.0
- Optional: If no `trigger-evals.json` exists, this weight is redistributed
- Measures: Whether the skill description correctly activates for relevant queries

### Quality Score (default weight: 0.3)
- Source: `grading.json` files from the grader agent
- Calculation: Mean pass rate across all grading results in the iteration directory
- Range: 0.0 - 1.0
- Measures: Overall quality of skill outputs beyond just passing assertions

## Composite Score

```
composite = w_assertion * assertion_score + w_trigger * trigger_score + w_quality * quality_score
```

### Weight Redistribution (No Trigger Evals)

When trigger evals are unavailable, the trigger weight is redistributed proportionally:

```
w_assertion_new = w_assertion / (w_assertion + w_quality)
w_quality_new = w_quality / (w_assertion + w_quality)
```

Default without trigger: assertion=0.625, quality=0.375

## Ratchet Mechanism

- **Score improves**: Commit SKILL.md changes, update best_score, reset plateau_count
- **Score stays same or decreases**: Revert SKILL.md via `git checkout`, increment plateau_count

## Convergence Criteria

The loop stops when ANY of these are met:
1. `best_score >= target_score` (target achieved)
2. `plateau_count >= max_plateau` (stuck in local optimum)
3. `iteration >= max_iterations` (budget exhausted)
