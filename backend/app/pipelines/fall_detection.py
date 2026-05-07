from dataclasses import dataclass
from typing import Optional


@dataclass
class FallDetector:
    drop_threshold: float = 0.18
    aspect_threshold: float = 1.2
    velocity_threshold: float = 0.12
    confirm_ms: int = 1500
    candidate_window_ms: int = 2500

    _prev_center_y: Optional[float] = None
    _prev_ts_ms: Optional[int] = None
    _candidate_since_ms: Optional[int] = None
    _lying_since_ms: Optional[int] = None

    def update(self, pose: Optional[dict], action: str, ts_ms: int) -> tuple[bool, float]:
        if pose is None:
            self._candidate_since_ms = None
            self._lying_since_ms = None
            return False, 0.0

        center_y = pose.get("center", (0.0, 0.0))[1]
        aspect_ratio = pose.get("aspect_ratio", 0.0)

        drop = False
        velocity = 0.0
        if self._prev_center_y is not None:
            drop = (center_y - self._prev_center_y) > self.drop_threshold
            if self._prev_ts_ms is not None:
                delta_ms = max(ts_ms - self._prev_ts_ms, 1)
                velocity = (center_y - self._prev_center_y) / (delta_ms / 1000.0)

        self._prev_center_y = center_y
        self._prev_ts_ms = ts_ms

        if action == "lying" and aspect_ratio > self.aspect_threshold:
            if self._lying_since_ms is None:
                self._lying_since_ms = ts_ms
        else:
            self._lying_since_ms = None

        if drop and velocity >= self.velocity_threshold and aspect_ratio > self.aspect_threshold:
            if self._candidate_since_ms is None:
                self._candidate_since_ms = ts_ms
        elif self._candidate_since_ms is not None:
            if ts_ms - self._candidate_since_ms > self.candidate_window_ms:
                self._candidate_since_ms = None

        if self._candidate_since_ms is not None and self._lying_since_ms is not None:
            if ts_ms - self._lying_since_ms >= self.confirm_ms:
                return True, 0.9

        return False, 0.0
