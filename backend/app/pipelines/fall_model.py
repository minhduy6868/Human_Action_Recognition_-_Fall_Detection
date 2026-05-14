from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class FallModel:
    model_path: str
    _model: object

    @classmethod
    def load(cls, model_path: str) -> "FallModel":
        try:
            import xgboost as xgb
        except ImportError:  # pragma: no cover - runtime dependency
            logger.warning(
                "xgboost not available: fall model will be disabled and predictions return 0.0"
            )
            return cls(model_path=model_path, _model=None)

        model = xgb.Booster()
        try:
            model.load_model(model_path)
        except Exception as exc:  # pragma: no cover - defensive: corrupted/missing file
            logger.exception("Failed to load xgboost model '%s': %s", model_path, exc)
            return cls(model_path=model_path, _model=None)

        return cls(model_path=model_path, _model=model)

    def predict(self, features: list[float]) -> float:
        try:
            import xgboost as xgb
        except ImportError as exc:  # pragma: no cover - runtime dependency
            # If xgboost is missing at predict time, return no-fall score.
            logger.debug("xgboost not installed at predict time; returning 0.0")
            return 0.0

        if self._model is None:
            logger.debug("No fall model loaded (None); returning 0.0")
            return 0.0

        arr = np.asarray(features, dtype=np.float32)
        if arr.ndim != 1:
            arr = arr.flatten()

        data = xgb.DMatrix(np.array([arr], dtype=np.float32))
        try:
            score = float(self._model.predict(data)[0])
        except Exception:
            logger.exception("Error during fall model prediction; returning 0.0")
            score = 0.0
        return score


def extract_fall_features(
    sequence: list[list[float]],
    visibility_threshold: float = 0.5,
) -> list[float]:
    if not sequence:
        return [0.0] * 10

    centers_y: list[float] = []
    aspects: list[float] = []
    heights: list[float] = []

    for frame in sequence:
        xs: list[float] = []
        ys: list[float] = []
        for idx in range(0, len(frame), 3):
            x_val = frame[idx]
            y_val = frame[idx + 1]
            vis_val = frame[idx + 2]
            if vis_val >= visibility_threshold:
                xs.append(x_val)
                ys.append(y_val)

        if not xs or not ys:
            continue

        x_min, x_max = min(xs), max(xs)
        y_min, y_max = min(ys), max(ys)
        height = max(y_max - y_min, 1e-6)
        width = max(x_max - x_min, 1e-6)
        centers_y.append(y_min + height / 2.0)
        aspects.append(width / height)
        heights.append(height)

    if not centers_y:
        return [0.0] * 10

    centers = np.array(centers_y, dtype=np.float32)
    aspects_arr = np.array(aspects, dtype=np.float32)
    heights_arr = np.array(heights, dtype=np.float32)

    deltas = np.diff(centers) if len(centers) > 1 else np.array([0.0], dtype=np.float32)
    drop_max = float(deltas.max(initial=0.0))
    drop_mean = float(deltas.mean())
    drop_std = float(deltas.std())

    aspect_max = float(aspects_arr.max(initial=0.0))
    aspect_mean = float(aspects_arr.mean())
    height_min = float(heights_arr.min(initial=0.0))
    height_mean = float(heights_arr.mean())

    lying_ratio = float((aspects_arr > 1.2).mean())

    return [
        drop_max,
        drop_mean,
        drop_std,
        aspect_max,
        aspect_mean,
        height_min,
        height_mean,
        float(centers[-1]),
        float(centers.mean()),
        lying_ratio,
    ]
