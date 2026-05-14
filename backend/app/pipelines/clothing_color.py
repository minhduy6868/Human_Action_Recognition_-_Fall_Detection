"""Clothing color detection using K-means clustering and HSV color space."""

import logging
from typing import Optional

import cv2
import numpy as np

logger = logging.getLogger(__name__)


class ClothingColorDetector:
    """Detect dominant clothing colors using K-means clustering + HSV naming."""

    def __init__(self, n_clusters: int = 3, max_pixels: int = 1024):
        self.n_clusters = n_clusters
        self.max_pixels = max_pixels
        # K-means termination criteria
        self._criteria = (
            cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER,
            10,
            1.0,
        )

    def detect_colors(
        self, frame: np.ndarray, bbox: tuple[float, float, float, float]
    ) -> dict:
        """
        Extract dominant clothing colors from person bbox.

        Args:
            frame: Input image (BGR)
            bbox: (x1, y1, x2, y2) in pixel coordinates

        Returns:
            Dictionary with "upper" and "lower" color names
        """
        x1, y1, x2, y2 = [int(v) for v in bbox]
        h = y2 - y1
        w = x2 - x1

        if h < 20 or w < 10:
            return {"upper": "unknown", "lower": "unknown"}

        # Exclude top 25% (head) and bottom 5% (feet) noise
        body_y1 = y1 + int(h * 0.25)
        body_y2 = y2 - int(h * 0.05)

        if body_y2 <= body_y1:
            return {"upper": "unknown", "lower": "unknown"}

        roi = frame[body_y1:body_y2, x1:x2]
        if roi.size == 0:
            return {"upper": "unknown", "lower": "unknown"}

        body_h = roi.shape[0]
        mid = body_h // 2

        upper_roi = roi[:mid]
        lower_roi = roi[mid:]

        return {
            "upper": self._get_dominant_color(upper_roi),
            "lower": self._get_dominant_color(lower_roi),
        }

    def _get_dominant_color(self, roi: np.ndarray) -> str:
        """Find dominant color using K-means clustering."""
        if roi.size == 0 or roi.shape[0] < 4 or roi.shape[1] < 4:
            return "unknown"

        # Downscale for speed
        scale = min(1.0, np.sqrt(self.max_pixels / (roi.shape[0] * roi.shape[1])))
        small = cv2.resize(
            roi,
            (max(4, int(roi.shape[1] * scale)), max(4, int(roi.shape[0] * scale))),
        )

        pixels = small.reshape(-1, 3).astype(np.float32)
        k = min(self.n_clusters, len(pixels))

        try:
            _, labels, centers = cv2.kmeans(
                pixels,
                k,
                None,
                self._criteria,
                3,
                cv2.KMEANS_RANDOM_CENTERS,
            )
        except cv2.error:
            return "unknown"

        counts = np.bincount(labels.flatten())
        dominant_bgr = centers[np.argmax(counts)].astype(np.uint8)
        return self._bgr_to_color_name(dominant_bgr)

    @staticmethod
    def _bgr_to_color_name(bgr: np.ndarray) -> str:
        """Convert a BGR pixel to a human-readable color name via HSV."""
        pixel = bgr.reshape(1, 1, 3)
        hsv = cv2.cvtColor(pixel, cv2.COLOR_BGR2HSV)[0][0]
        h, s, v = int(hsv[0]), int(hsv[1]), int(hsv[2])

        # Achromatic colours first (low saturation or extreme brightness)
        if v < 40:
            return "black"
        if s < 35:
            if v > 200:
                return "white"
            if v > 130:
                return "gray"
            return "dark gray"

        # Chromatic – classify by hue (OpenCV H: 0-179)
        if h < 8 or h >= 172:
            return "red"
        if h < 18:
            return "orange"
        if h < 33:
            return "yellow"
        if h < 85:
            # Distinguish dark green / olive
            if v < 80:
                return "dark green"
            return "green"
        if h < 100:
            return "cyan"
        if h < 130:
            # Distinguish navy vs sky blue
            if v < 80:
                return "navy"
            return "blue"
        if h < 150:
            return "purple"
        if h < 165:
            # Low saturation pink-ish → beige/brown range
            if s < 80:
                return "pink"
            return "magenta"
        return "pink"


# Singleton instance
_detector: Optional[ClothingColorDetector] = None


def get_clothing_detector() -> ClothingColorDetector:
    """Get or create clothing color detector singleton."""
    global _detector
    if _detector is None:
        _detector = ClothingColorDetector()
    return _detector
