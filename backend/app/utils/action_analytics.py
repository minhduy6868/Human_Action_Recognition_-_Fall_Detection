"""Shared utilities for action and timeline analysis."""

from app.models.schemas import RealtimeStatus


def durations_by_action(items: list[RealtimeStatus]) -> dict[str, int]:
    """Calculate duration (in ms) for each action in a sequence.
    
    Uses median diff between timestamps to estimate duration for the last item.
    """
    if not items:
        return {}

    durations: dict[str, int] = {}
    if len(items) == 1:
        durations[items[0].action] = 1
        return durations

    diffs = [
        max(items[i + 1].timestamp_ms - items[i].timestamp_ms, 1)
        for i in range(len(items) - 1)
    ]
    median_diff = sorted(diffs)[len(diffs) // 2]

    for idx, item in enumerate(items):
        if idx < len(items) - 1:
            delta = max(items[idx + 1].timestamp_ms - item.timestamp_ms, 1)
        else:
            delta = max(median_diff, 1)
        durations[item.action] = durations.get(item.action, 0) + delta

    return durations


def durations_by_action_with_total(items: list[RealtimeStatus]) -> tuple[int, dict[str, int]]:
    """Calculate duration for each action and return total duration as well.
    
    Returns:
        Tuple of (total_ms, durations_dict)
    """
    durations = durations_by_action(items)
    return sum(durations.values()), durations
