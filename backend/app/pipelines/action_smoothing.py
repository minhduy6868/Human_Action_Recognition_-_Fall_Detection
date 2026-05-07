from __future__ import annotations

from collections import defaultdict
from typing import Iterable


def smooth_action(
    history: Iterable[tuple[str, float]],
    min_confidence: float,
) -> tuple[str, float]:
    weights: dict[str, float] = defaultdict(float)
    counts: dict[str, int] = defaultdict(int)

    for label, confidence in history:
        weights[label] += confidence
        counts[label] += 1

    if not weights:
        return "unknown", 0.0

    best_label = max(weights, key=weights.get)
    avg_confidence = weights[best_label] / max(counts[best_label], 1)

    if avg_confidence < min_confidence:
        return "unknown", avg_confidence

    return best_label, min(1.0, avg_confidence)
