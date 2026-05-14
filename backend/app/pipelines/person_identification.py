"""Person identification and tracking with embeddings."""

import logging
from typing import Optional

import cv2
import numpy as np

logger = logging.getLogger(__name__)


class PersonIdentifier:
    """Identify and track persons using visual features."""

    def __init__(self, embedding_dim: int = 128, max_history: int = 500):
        self.embedding_dim = embedding_dim
        self.max_history = max_history
        self.person_embeddings: dict[str, np.ndarray] = {}
        self.person_features: dict[str, dict] = {}

    def extract_person_features(
        self, frame: np.ndarray, bbox: tuple[float, float, float, float], track_id: str
    ) -> dict:
        """
        Extract person features (simplified without face recognition).
        Uses spatial histogram as a simple embedding.

        Args:
            frame: Input image
            bbox: Bounding box (x1, y1, x2, y2)
            track_id: Person track ID

        Returns:
            Dictionary with person features
        """
        x1, y1, x2, y2 = [int(v) for v in bbox]
        x1, y1, x2, y2 = max(0, x1), max(0, y1), min(frame.shape[1], x2), min(frame.shape[0], y2)

        roi = frame[y1:y2, x1:x2]
        if roi.size == 0:
            return {}

        # Create simple color histogram as embedding
        embedding = self._create_histogram_embedding(roi)

        if track_id in self.person_embeddings:
            # Calculate similarity with existing embedding
            similarity = self._cosine_similarity(embedding, self.person_embeddings[track_id])
            logger.debug(f"Person {track_id} similarity: {similarity:.3f}")

        # Update embedding (exponential moving average)
        if track_id in self.person_embeddings:
            self.person_embeddings[track_id] = 0.7 * self.person_embeddings[
                track_id
            ] + 0.3 * embedding
        else:
            self.person_embeddings[track_id] = embedding

        # Store features
        self.person_features[track_id] = {
            "bbox": (x1, y1, x2, y2),
            "height": y2 - y1,
            "width": x2 - x1,
            "area": (x2 - x1) * (y2 - y1),
        }

        return self.person_features.get(track_id, {})

    def _create_histogram_embedding(self, roi: np.ndarray) -> np.ndarray:
        """Create a simple embedding using color histograms."""
        # Resize for consistency
        resized = cv2.resize(roi, (32, 64))

        # Split into B, G, R channels
        b, g, r = cv2.split(resized)

        # Create histograms (8 bins each = 24 values total)
        hist_b = cv2.calcHist([b], [0], None, [8], [0, 256])
        hist_g = cv2.calcHist([g], [0], None, [8], [0, 256])
        hist_r = cv2.calcHist([r], [0], None, [8], [0, 256])

        # Concatenate and normalize
        embedding = np.concatenate([hist_b, hist_g, hist_r]).flatten()
        embedding = embedding / (np.linalg.norm(embedding) + 1e-8)

        return embedding[:128]  # Limit to 128 dimensions

    def _cosine_similarity(self, vec1: np.ndarray, vec2: np.ndarray) -> float:
        """Calculate cosine similarity between two vectors."""
        dot_product = np.dot(vec1, vec2)
        norm1 = np.linalg.norm(vec1)
        norm2 = np.linalg.norm(vec2)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        return float(dot_product / (norm1 * norm2))

    def get_embedding_vector(self, track_id: str) -> Optional[np.ndarray]:
        """Return the current EMA embedding for a track, if any."""
        emb = self.person_embeddings.get(track_id)
        return None if emb is None else emb.copy()

    def get_person_info(self, track_id: str) -> Optional[dict]:
        """Get stored information about a person."""
        return self.person_features.get(track_id)

    def clear_old_persons(self, max_age: int = 1000):
        """Remove old person embeddings (optional cleanup)."""
        if len(self.person_embeddings) > self.max_history:
            # Keep only recent N persons
            recent_ids = list(self.person_embeddings.keys())[-self.max_history :]
            self.person_embeddings = {
                tid: self.person_embeddings[tid] for tid in recent_ids if tid in self.person_embeddings
            }
            self.person_features = {
                tid: self.person_features[tid] for tid in recent_ids if tid in self.person_features
            }


# Singleton instance
_identifier = None


def get_person_identifier() -> PersonIdentifier:
    """Get or create person identifier."""
    global _identifier
    if _identifier is None:
        _identifier = PersonIdentifier()
    return _identifier
