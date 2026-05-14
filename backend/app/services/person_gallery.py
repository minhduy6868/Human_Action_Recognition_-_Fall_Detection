"""SQLite-backed gallery for persistent person_id from visual embeddings."""

from __future__ import annotations

import logging
import sqlite3
import time
import uuid
from pathlib import Path

import numpy as np

logger = logging.getLogger(__name__)


class PersonGalleryStore:
    """Match new embeddings to known persons or register a new gallery id."""

    def __init__(self, db_path: str, match_threshold: float) -> None:
        self.db_path = db_path
        self.match_threshold = match_threshold
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS persons (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    gallery_uuid TEXT UNIQUE NOT NULL,
                    embedding BLOB NOT NULL,
                    created_ts REAL NOT NULL,
                    last_seen_ts REAL NOT NULL
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_persons_last_seen ON persons(last_seen_ts)"
            )

    def _normalize(self, embedding: np.ndarray) -> np.ndarray:
        flat = embedding.astype(np.float32).flatten()
        n = float(np.linalg.norm(flat) + 1e-8)
        return flat / n

    def match_or_register(self, embedding: np.ndarray) -> tuple[str, float]:
        """
        Returns (person_id, similarity).
        similarity is best match score in [0,1] for cosine; 1.0 for new registrations.
        """
        emb = self._normalize(embedding)
        now = time.time()

        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute(
                "SELECT gallery_uuid, embedding FROM persons"
            ).fetchall()

            best_id: str | None = None
            best_sim = -1.0
            for gid, blob in rows:
                other = np.frombuffer(blob, dtype=np.float32)
                if other.shape != emb.shape:
                    continue
                sim = float(np.dot(emb, other))
                if sim > best_sim:
                    best_sim = sim
                    best_id = gid

            if best_id is not None and best_sim >= self.match_threshold:
                conn.execute(
                    "UPDATE persons SET last_seen_ts = ? WHERE gallery_uuid = ?",
                    (now, best_id),
                )
                conn.commit()
                return best_id, best_sim

            new_id = f"gallery_{uuid.uuid4().hex[:12]}"
            conn.execute(
                "INSERT INTO persons (gallery_uuid, embedding, created_ts, last_seen_ts) VALUES (?, ?, ?, ?)",
                (new_id, emb.tobytes(), now, now),
            )
            conn.commit()
            logger.debug("Registered new gallery person %s", new_id)
            return new_id, 1.0
