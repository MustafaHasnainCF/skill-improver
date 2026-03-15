#!/usr/bin/env python3
"""
Compute composite score from benchmark results.

Combines assertion pass rate, trigger accuracy, and quality (claims verification)
into a weighted composite score.

Usage:
    python compute-score.py --benchmark path/to/benchmark.json [OPTIONS]

Output:
    JSON to stdout with composite, component scores, and weights used.
"""

import argparse
import json
import sys
from pathlib import Path


def parse_weights(weights_str: str) -> dict[str, float]:
    """Parse weight spec like 'assertion:0.5,trigger:0.2,quality:0.3'."""
    weights = {}
    for pair in weights_str.split(","):
        pair = pair.strip()
        if ":" not in pair:
            continue
        key, val = pair.split(":", 1)
        weights[key.strip()] = float(val.strip())
    return weights


def compute_assertion_score(benchmark: dict) -> float:
    """Compute mean pass rate from benchmark.json runs."""
    run_summary = benchmark.get("run_summary", {})

    # Try to find a config with pass_rate stats
    for config_name, config_data in run_summary.items():
        if config_name == "delta":
            continue
        if isinstance(config_data, dict) and "pass_rate" in config_data:
            return config_data["pass_rate"].get("mean", 0.0)

    # Fallback: compute from individual runs
    runs = benchmark.get("runs", [])
    if not runs:
        return 0.0

    pass_rates = [r.get("result", {}).get("pass_rate", 0.0) for r in runs]
    return sum(pass_rates) / len(pass_rates) if pass_rates else 0.0


def compute_trigger_score(trigger_results: dict | None) -> float | None:
    """Compute trigger accuracy from run_eval.py results."""
    if trigger_results is None:
        return None

    summary = trigger_results.get("summary", {})
    total = summary.get("total", 0)
    passed = summary.get("passed", 0)

    if total == 0:
        return None

    return passed / total


def compute_quality_score(benchmark_dir: Path) -> float:
    """Compute quality score from grading.json claims verification rates.

    Walks the benchmark directory for grading.json files and computes
    the average pass_rate across all grading results.
    """
    pass_rates = []

    for grading_file in benchmark_dir.rglob("grading.json"):
        try:
            with open(grading_file) as f:
                grading = json.load(f)
            summary = grading.get("summary", {})
            rate = summary.get("pass_rate", None)
            if rate is not None:
                pass_rates.append(rate)
        except (json.JSONDecodeError, OSError):
            continue

    if not pass_rates:
        return 0.0

    return sum(pass_rates) / len(pass_rates)


def compute_composite(
    assertion_score: float,
    trigger_score: float | None,
    quality_score: float,
    weights: dict[str, float],
) -> tuple[float, dict[str, float]]:
    """Compute weighted composite score.

    If trigger_score is None, redistributes trigger weight proportionally
    to assertion and quality.

    Returns (composite_score, actual_weights_used).
    """
    if trigger_score is not None:
        # Use all three components
        total_weight = sum(weights.values())
        w_assertion = weights.get("assertion", 0.5) / total_weight
        w_trigger = weights.get("trigger", 0.2) / total_weight
        w_quality = weights.get("quality", 0.3) / total_weight

        composite = (
            w_assertion * assertion_score
            + w_trigger * trigger_score
            + w_quality * quality_score
        )
        actual_weights = {
            "assertion": round(w_assertion, 4),
            "trigger": round(w_trigger, 4),
            "quality": round(w_quality, 4),
        }
    else:
        # Redistribute trigger weight proportionally
        w_assertion_raw = weights.get("assertion", 0.5)
        w_quality_raw = weights.get("quality", 0.3)
        total = w_assertion_raw + w_quality_raw

        if total == 0:
            w_assertion = 0.5
            w_quality = 0.5
        else:
            w_assertion = w_assertion_raw / total
            w_quality = w_quality_raw / total

        composite = w_assertion * assertion_score + w_quality * quality_score
        actual_weights = {
            "assertion": round(w_assertion, 4),
            "trigger": 0.0,
            "quality": round(w_quality, 4),
        }

    return round(composite, 4), actual_weights


def main():
    parser = argparse.ArgumentParser(
        description="Compute composite score from benchmark results"
    )
    parser.add_argument(
        "--benchmark",
        required=True,
        type=Path,
        help="Path to benchmark.json",
    )
    parser.add_argument(
        "--trigger-results",
        type=Path,
        default=None,
        help="Path to trigger eval results JSON (optional)",
    )
    parser.add_argument(
        "--benchmark-dir",
        type=Path,
        default=None,
        help="Path to benchmark directory for quality score (defaults to benchmark.json parent)",
    )
    parser.add_argument(
        "--weights",
        default="assertion:0.5,trigger:0.2,quality:0.3",
        help="Score weights as key:value pairs",
    )

    args = parser.parse_args()

    if not args.benchmark.exists():
        print(f"Error: benchmark file not found: {args.benchmark}", file=sys.stderr)
        sys.exit(1)

    # Load benchmark
    with open(args.benchmark) as f:
        benchmark = json.load(f)

    # Load trigger results if provided
    trigger_results = None
    if args.trigger_results and args.trigger_results.exists():
        with open(args.trigger_results) as f:
            trigger_results = json.load(f)

    # Determine benchmark directory for quality score
    benchmark_dir = args.benchmark_dir or args.benchmark.parent

    # Compute component scores
    assertion_score = compute_assertion_score(benchmark)
    trigger_score = compute_trigger_score(trigger_results)
    quality_score = compute_quality_score(benchmark_dir)

    # Parse weights
    weights = parse_weights(args.weights)

    # Compute composite
    composite, actual_weights = compute_composite(
        assertion_score, trigger_score, quality_score, weights
    )

    # Output result
    result = {
        "composite": composite,
        "assertion_score": round(assertion_score, 4),
        "trigger_score": round(trigger_score, 4) if trigger_score is not None else None,
        "quality_score": round(quality_score, 4),
        "weights_used": actual_weights,
    }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
