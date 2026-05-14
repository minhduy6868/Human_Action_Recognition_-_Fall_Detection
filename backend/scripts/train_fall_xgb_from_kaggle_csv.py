"""
Train fall_xgb.json from Kaggle-style keypoint CSVs (e.g. payutch/fall-video-dataset).

Dataset layout (typical):
  <root>/Fall/Keypoints_CSV/*.csv          -> label 1 (fall)
  <root>/NonFall/Keypoints_CSV/*.csv      -> label 0 (ADL / no fall)  [names may vary]

The Kaggle archive is ~15 GB — ensure free disk before --download.

Usage:
  pip install kagglehub xgboost pandas scikit-learn
  # If disk is tight: train a placeholder model (not real-world accurate):
  python scripts/train_fall_xgb_from_kaggle_csv.py --synthetic

  python scripts/train_fall_xgb_from_kaggle_csv.py --download
  python scripts/train_fall_xgb_from_kaggle_csv.py --data_root "D:/datasets/fall-video-dataset"

Or after kagglehub.dataset_download("payutch/fall-video-dataset"):
  python scripts/train_fall_xgb_from_kaggle_csv.py --data_root "<printed_path>"
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
import xgboost as xgb

# Repo root: backend/scripts -> backend
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.pipelines.fall_model import extract_fall_features  # noqa: E402


def _norm_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = [str(c).strip().lower() for c in df.columns]
    return df


def csv_to_pose_sequence(csv_path: Path) -> list[list[float]] | None:
    """
    Build list[frame] of flattened [x,y,conf]*17 in Keypoint order 0..16.
    Expects columns: frame, keypoint, x, y, confidence (case-insensitive).
    """
    try:
        df = pd.read_csv(csv_path)
    except Exception:
        return None
    df = _norm_columns(df)
    required = {"frame", "keypoint", "x", "y", "confidence"}
    if not required.issubset(df.columns):
        return None

    df["keypoint"] = pd.to_numeric(df["keypoint"], errors="coerce")
    df = df.dropna(subset=["keypoint"])
    df["keypoint"] = df["keypoint"].astype(int)
    df["frame"] = pd.to_numeric(df["frame"], errors="coerce").astype(int)

    frames = sorted(df["frame"].unique())
    seq: list[list[float]] = []
    for fr in frames:
        sub = df[df["frame"] == fr].sort_values("keypoint")
        if len(sub) < 17:
            continue
        # take first 17 rows if duplicates
        sub = sub.drop_duplicates(subset=["keypoint"]).head(17)
        if len(sub) != 17 or set(sub["keypoint"].tolist()) != set(range(17)):
            continue
        sub = sub.sort_values("keypoint")
        flat: list[float] = []
        for _, row in sub.iterrows():
            flat.extend(
                [
                    float(row["x"]),
                    float(row["y"]),
                    float(row["confidence"]),
                ]
            )
        if len(flat) == 51:
            seq.append(flat)
    if len(seq) < 8:
        return None
    return seq


def iter_windows(
    seq: list[list[float]],
    window: int,
    stride: int,
) -> list[list[list[float]]]:
    """Sliding windows; if shorter than window but >= 8 frames, use full sequence once."""
    if len(seq) < 8:
        return []
    if len(seq) < window:
        return [seq]
    out: list[list[list[float]]] = []
    for i in range(0, len(seq) - window + 1, max(1, stride)):
        out.append(seq[i : i + window])
    if not out:
        out.append(seq[-window:])
    return out


def collect_samples(
    data_root: Path,
    pos_dirs: list[Path],
    neg_dirs: list[Path],
    window: int,
    stride: int,
    max_csv_per_class: int | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    X_rows: list[list[float]] = []
    y_rows: list[int] = []

    def walk_csv(dirs: list[Path], label: int) -> None:
        for d in dirs:
            if not d.exists():
                continue
            paths = sorted(d.rglob("*.csv"))
            if max_csv_per_class is not None:
                paths = paths[: max_csv_per_class]
            for csv_path in paths:
                seq = csv_to_pose_sequence(csv_path)
                if not seq:
                    continue
                for w in iter_windows(seq, window=window, stride=stride):
                    feat = extract_fall_features(w)
                    X_rows.append(feat)
                    y_rows.append(label)

    walk_csv(pos_dirs, 1)
    walk_csv(neg_dirs, 0)

    if len(X_rows) < 20:
        raise RuntimeError(
            f"Too few samples: {len(X_rows)}. Check --data_root, positive/negative dirs, and CSV format."
        )
    return np.asarray(X_rows, dtype=np.float32), np.asarray(y_rows, dtype=np.int32)


def default_pos_neg_dirs(data_root: Path) -> tuple[list[Path], list[Path]]:
    """Guess Keypoints_CSV folders: parent folder name Fall vs NonFall/ADL/..."""
    neg_parents = frozenset(
        {
            "nonfall",
            "nofall",
            "negative",
            "adl",
            "normal",
            "confound",
        }
    )
    pos: list[Path] = []
    neg: list[Path] = []
    for kp in data_root.rglob("Keypoints_CSV"):
        if not kp.is_dir():
            continue
        parent = kp.parent.name.lower().replace(" ", "")
        parent_norm = parent.replace("-", "").replace("_", "")
        if parent_norm == "fall":
            pos.append(kp)
        elif parent_norm in neg_parents or parent_norm.startswith("non"):
            neg.append(kp)
    return list(dict.fromkeys(pos)), list(dict.fromkeys(neg))


def download_kaggle_dataset() -> Path:
    import kagglehub

    path = kagglehub.dataset_download("payutch/fall-video-dataset")
    return Path(path)


def _synth_pose_sequence(is_fall: bool, n_frames: int, rng: np.random.Generator) -> list[list[float]]:
    """Toy skeleton paths so extract_fall_features separates fall vs non-fall."""
    out: list[list[float]] = []
    for t in range(n_frames):
        row: list[float] = []
        for i in range(17):
            x = float(0.42 + rng.normal(0, 0.012) + (i % 4) * 0.018)
            y = float(0.24 + (i // 4) * 0.048 + rng.normal(0, 0.008))
            row.extend([x, y, float(0.92 + rng.random() * 0.06)])
        if is_fall and t >= n_frames // 2:
            mid = t - n_frames // 2
            for k in range(17):
                j = k * 3
                row[j + 1] = min(0.99, row[j + 1] + 0.038 * mid)
                row[j] = float(row[j] + rng.normal(0, 0.05 * (1 + mid)))
        out.append(row)
    return out


def synthetic_feature_dataset(n_samples: int, window: int, seed: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    X_rows: list[list[float]] = []
    y_rows: list[int] = []
    for idx in range(n_samples):
        is_fall = idx % 2 == 1
        n_frames = int(rng.integers(max(window, 12), window + 20))
        seq = _synth_pose_sequence(is_fall=is_fall, n_frames=n_frames, rng=rng)
        for w in iter_windows(seq, window=window, stride=max(5, window // 3)):
            X_rows.append(extract_fall_features(w))
            y_rows.append(1 if is_fall else 0)
            break
    return np.asarray(X_rows, dtype=np.float32), np.asarray(y_rows, dtype=np.int32)


def train_xgb_and_save(X: np.ndarray, y: np.ndarray, out_path: Path, seed: int) -> None:
    print("Samples:", X.shape[0], " features:", X.shape[1], " fall ratio:", float(y.mean()))

    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, random_state=seed, stratify=y
    )

    dtrain = xgb.DMatrix(X_train, label=y_train)
    dval = xgb.DMatrix(X_val, label=y_val)

    params = {
        "objective": "binary:logistic",
        "eval_metric": "aucpr",
        "max_depth": 5,
        "eta": 0.1,
        "subsample": 0.9,
        "colsample_bytree": 0.9,
        "seed": seed,
    }
    booster = xgb.train(
        params,
        dtrain,
        num_boost_round=200,
        evals=[(dval, "val")],
        early_stopping_rounds=25,
        verbose_eval=20,
    )

    y_prob = booster.predict(dval)
    y_hat = (y_prob >= 0.5).astype(int)
    print(classification_report(y_val, y_hat, digits=4))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    booster.save_model(str(out_path))
    print("Saved:", out_path.resolve())


def main() -> None:
    ap = argparse.ArgumentParser(description="Train XGBoost fall detector from keypoint CSVs.")
    ap.add_argument("--download", action="store_true", help="Download dataset via kagglehub")
    ap.add_argument("--data_root", type=str, default="", help="Unzipped dataset root")
    ap.add_argument("--pos_dir", action="append", default=[], help="Keypoints_CSV dir(s) for fall (label 1). Repeatable.")
    ap.add_argument("--neg_dir", action="append", default=[], help="Keypoints_CSV dir(s) for non-fall (label 0). Repeatable.")
    ap.add_argument("--window", type=int, default=30, help="Pose frames per sample (match ACTION_WINDOW_FRAMES)")
    ap.add_argument("--stride", type=int, default=10, help="Sliding window stride on long clips")
    ap.add_argument("--out", type=str, default=str(BACKEND_ROOT / "models" / "fall_xgb.json"))
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument(
        "--synthetic",
        action="store_true",
        help="Train on synthetic pose windows (no Kaggle). For pipeline smoke-test only.",
    )
    ap.add_argument("--synthetic_samples", type=int, default=2800)
    ap.add_argument(
        "--max_csv_per_class",
        type=int,
        default=0,
        help="Max CSV files per class (0 = all). Use after manual partial copy to save time.",
    )
    args = ap.parse_args()

    out_path = Path(args.out)

    if args.synthetic:
        print("Synthetic training (not calibrated for real CCTV).")
        X, y = synthetic_feature_dataset(args.synthetic_samples, args.window, args.seed)
        train_xgb_and_save(X, y, out_path, args.seed)
        return

    if args.download:
        root = download_kaggle_dataset()
        print("Downloaded to:", root)
        if not args.data_root:
            args.data_root = str(root)

    if not args.data_root:
        ap.error("Provide --data_root, use --download, or use --synthetic")

    data_root = Path(args.data_root).resolve()
    pos_dirs = [Path(p).resolve() for p in args.pos_dir]
    neg_dirs = [Path(p).resolve() for p in args.neg_dir]

    if not pos_dirs or not neg_dirs:
        auto_pos, auto_neg = default_pos_neg_dirs(data_root)
        if not pos_dirs:
            pos_dirs = auto_pos
        if not neg_dirs:
            neg_dirs = auto_neg

    print("data_root:", data_root)
    print("positive Keypoints_CSV dirs:", pos_dirs)
    print("negative Keypoints_CSV dirs:", neg_dirs)

    if not pos_dirs or not neg_dirs:
        raise SystemExit(
            "Could not find positive/negative Keypoints_CSV folders. "
            "Pass explicit --pos_dir and --neg_dir (each can repeat), e.g.\n"
            f'  --pos_dir "{data_root}/Fall/Keypoints_CSV" '
            f'--neg_dir "{data_root}/NonFall/Keypoints_CSV"'
        )

    max_csv = args.max_csv_per_class if args.max_csv_per_class > 0 else None
    X, y = collect_samples(
        data_root,
        pos_dirs,
        neg_dirs,
        window=args.window,
        stride=args.stride,
        max_csv_per_class=max_csv,
    )
    train_xgb_and_save(X, y, out_path, args.seed)


if __name__ == "__main__":
    main()
