from __future__ import annotations

from datetime import datetime

from app.db.models import DetectionLog
from app.models.schemas import (
    ActionSegment,
    DetectedObject,
    FallEvent,
    NotableMoment,
    PersonAction,
    PersonClothing,
    RealtimeStatus,
)
from app.utils.action_analytics import durations_by_action

_SKIP_ACTIONS = frozenset({"unknown", "idle", "none", ""})

_COLOR_VI = {
    "white": "trắng",
    "black": "đen",
    "red": "đỏ",
    "blue": "xanh",
    "green": "xanh lá",
    "yellow": "vàng",
    "orange": "cam",
    "gray": "xám",
    "grey": "xám",
    "brown": "nâu",
    "purple": "tím",
    "pink": "hồng",
}

_ACTION_VI = {
    "walking": "đi",
    "standing": "đứng",
    "sitting": "ngồi",
    "lying": "nằm",
    "running": "chạy",
    "crouching": "cúi",
    "fall": "té ngã",
}


def format_time_vi(ts_ms: int) -> str:
    try:
        return datetime.fromtimestamp(ts_ms / 1000.0).strftime("%Hh%M")
    except Exception:
        return "?h??"


def _normalize_action(action: str) -> str:
    return (action or "unknown").strip().lower()


def _normalize_color(color: str) -> str:
    value = (color or "unknown").strip().lower()
    return value if value else "unknown"


def color_label_vi(color: str) -> str:
    key = _normalize_color(color)
    return _COLOR_VI.get(key, key if key != "unknown" else "")


def action_label_vi(action: str) -> str:
    key = _normalize_action(action)
    return _ACTION_VI.get(key, f"đang {key}")


def subsample_items(items: list[RealtimeStatus], max_frames: int = 1200) -> list[RealtimeStatus]:
    ordered = sorted(items, key=lambda item: item.timestamp_ms)
    if len(ordered) <= max_frames:
        return ordered
    step = max(1, len(ordered) // max_frames)
    return ordered[::step]


def _iter_people_frames(item: RealtimeStatus):
    if item.people:
        for person in item.people:
            action = _normalize_action(person.action)
            if action in _SKIP_ACTIONS:
                continue
            yield (
                str(person.track_id or item.track_id or "0"),
                action,
                _normalize_color(person.clothing.upper),
                bool(person.fall),
            )
        return
    action = _normalize_action(item.action)
    if action in _SKIP_ACTIONS:
        return
    yield (
        str(item.track_id or "0"),
        action,
        "unknown",
        bool(item.fall),
    )


def build_person_track_segments(items: list[RealtimeStatus]) -> dict[str, list[dict]]:
    tracks: dict[str, list[dict]] = {}
    for item in subsample_items(items):
        ts = item.timestamp_ms
        for track_id, action, color, fall in _iter_people_frames(item):
            segments = tracks.setdefault(track_id, [])
            if (
                segments
                and segments[-1]["action"] == action
                and segments[-1]["color"] == color
            ):
                segments[-1]["end_ms"] = ts
                segments[-1]["fall"] = segments[-1]["fall"] or fall
            else:
                segments.append(
                    {
                        "action": action,
                        "color": color,
                        "start_ms": ts,
                        "end_ms": ts,
                        "fall": fall,
                    }
                )
    return tracks


def _narrative_for_track(segments: list[dict]) -> str | None:
    if not segments:
        return None
    color_word = color_label_vi(segments[0]["color"])
    subject = f"người mặc áo {color_word}" if color_word else "một người"
    clauses: list[str] = []
    for idx, seg in enumerate(segments):
        act = action_label_vi(seg["action"])
        t = format_time_vi(seg["start_ms"])
        if idx == 0:
            clauses.append(f"Vào {t}, {subject} đang {act}")
        else:
            clauses.append(f"rồi khoảng {t} chuyển sang {act}")
        if seg.get("fall"):
            clauses.append("có dấu hiệu té ngã")
    text = ", ".join(clauses)
    return text[0].upper() + text[1:] + "." if text else None


def build_parallel_presence_lines(items: list[RealtimeStatus], *, max_lines: int = 6) -> list[str]:
    lines: list[str] = []
    last_signature = ""
    for item in subsample_items(items):
        people: list[tuple[str, str, bool]] = []
        for _, action, color, fall in _iter_people_frames(item):
            people.append((color, action, fall))
        if len(people) < 2:
            continue
        colors = {color for color, _, _ in people if color != "unknown"}
        if len(colors) < 2 and len(people) < 2:
            continue
        parts: list[str] = []
        for color, action, fall in people:
            color_word = color_label_vi(color)
            act = action_label_vi(action)
            label = f"người áo {color_word} ({act})" if color_word else f"người ({act})"
            if fall:
                label += ", có dấu hiệu té"
            parts.append(label)
        signature = "|".join(sorted(parts))
        if signature == last_signature:
            continue
        last_signature = signature
        t = format_time_vi(item.timestamp_ms)
        lines.append(f"Lúc {t}, song song có {', '.join(parts)}.")
        if len(lines) >= max_lines:
            break
    return lines


def log_narrative_lines_from_items(items: list[RealtimeStatus]) -> list[str]:
    if not items:
        return []
    tracks = build_person_track_segments(items)
    ordered_tracks = sorted(
        tracks.items(),
        key=lambda pair: pair[1][0]["start_ms"] if pair[1] else 0,
    )
    lines: list[str] = []
    for _, segments in ordered_tracks[:8]:
        line = _narrative_for_track(segments)
        if line:
            lines.append(line)
    lines.extend(build_parallel_presence_lines(items))
    return lines[:16]


def log_row_to_status(row: DetectionLog) -> RealtimeStatus:
    people: list[PersonAction] = []
    for payload in row.people_json or []:
        if not isinstance(payload, dict):
            continue
        try:
            clothing_raw = payload.get("clothing") or {}
            clothing = (
                PersonClothing(**clothing_raw)
                if isinstance(clothing_raw, dict)
                else PersonClothing()
            )
            people.append(
                PersonAction(
                    track_id=str(payload.get("track_id", row.track_id)),
                    action=str(payload.get("action", row.action)),
                    confidence=float(payload.get("confidence", row.confidence)),
                    fall=bool(payload.get("fall", row.fall)),
                    fall_confidence=float(payload.get("fall_confidence", row.fall_confidence)),
                    bbox_x1=float(payload.get("bbox_x1", 0.0)),
                    bbox_y1=float(payload.get("bbox_y1", 0.0)),
                    bbox_x2=float(payload.get("bbox_x2", 0.0)),
                    bbox_y2=float(payload.get("bbox_y2", 0.0)),
                    clothing=clothing,
                    person_id=str(payload.get("person_id", "")),
                )
            )
        except Exception:
            continue

    objects: list[DetectedObject] = []
    for payload in row.objects_json or []:
        if not isinstance(payload, dict):
            continue
        try:
            objects.append(DetectedObject(**payload))
        except Exception:
            continue

    return RealtimeStatus(
        action=row.action,
        confidence=row.confidence,
        fall=row.fall,
        fall_confidence=row.fall_confidence,
        timestamp_ms=row.timestamp_ms,
        track_id=row.track_id,
        objects=objects,
        people=people,
    )


def segments_from_items(items: list[RealtimeStatus]) -> list[ActionSegment]:
    if not items:
        return []

    segments: list[ActionSegment] = []
    current_action = items[0].action
    start_ms = items[0].timestamp_ms
    last_ms = start_ms

    for item in items[1:]:
        if item.action != current_action:
            segments.append(
                ActionSegment(action=current_action, start_ms=start_ms, end_ms=last_ms)
            )
            current_action = item.action
            start_ms = item.timestamp_ms
        last_ms = item.timestamp_ms

    segments.append(ActionSegment(action=current_action, start_ms=start_ms, end_ms=last_ms))
    return segments


def notable_moments_from_items(items: list[RealtimeStatus]) -> list[NotableMoment]:
    notable: list[NotableMoment] = []
    last_seen: dict[str, tuple[str, str]] = {}
    for item in subsample_items(items, max_frames=1500):
        for track_id, action, color, _ in _iter_people_frames(item):
            prev = last_seen.get(track_id)
            if prev == (action, color):
                continue
            last_seen[track_id] = (action, color)
            notable.append(
                NotableMoment(
                    timestamp_ms=item.timestamp_ms,
                    time_label=format_time_vi(item.timestamp_ms),
                    action=action,
                    upper_color=color,
                    track_id=track_id,
                )
            )
    return notable[-24:]


def merge_status_items(
    stored: list[RealtimeStatus],
    live: list[RealtimeStatus],
) -> list[RealtimeStatus]:
    if not live:
        return sorted(stored, key=lambda item: item.timestamp_ms)
    if not stored:
        return sorted(live, key=lambda item: item.timestamp_ms)

    latest_stored = max(item.timestamp_ms for item in stored)
    merged = list(stored)
    for item in live:
        if item.timestamp_ms > latest_stored:
            merged.append(item)
    return sorted(merged, key=lambda item: item.timestamp_ms)
