from dataclasses import dataclass
from typing import Optional


@dataclass
class FallDetector:
    drop_threshold: float = 0.18
    aspect_threshold: float = 1.2
    confirm_frames: int = 6

    _prev_center_y: Optional[float] = None
    _candidate_frames: int = 0

    def update(self, pose: Optional[dict], action: str, ts_ms: int) -> tuple[bool, float]:
        if pose is None:
            self._candidate_frames = max(0, self._candidate_frames - 1)
            return False, 0.0

        center_y = pose.get("center", (0.0, 0.0))[1]
        aspect_ratio = pose.get("aspect_ratio", 0.0)

        drop = False
        if self._prev_center_y is not None:
            drop = (center_y - self._prev_center_y) > self.drop_threshold

        self._prev_center_y = center_y

        if action == "lying" and aspect_ratio > self.aspect_threshold and drop:
            self._candidate_frames += 1
        else:
            self._candidate_frames = max(0, self._candidate_frames - 1)

        if self._candidate_frames >= self.confirm_frames:
            return True, 0.9

        return False, 0.0
