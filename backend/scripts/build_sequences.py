import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np


def main() -> None:
    parser = argparse.ArgumentParser(description="Build action sequences from keypoint JSONL")
    parser.add_argument(
        "--input",
        required=True,
        nargs="+",
        help="Input JSONL files",
    )
    parser.add_argument("--output", required=True, help="Output NPZ path")
    parser.add_argument("--window", type=int, default=30)
    parser.add_argument("--stride", type=int, default=5)
    args = parser.parse_args()

    sequences: list[np.ndarray] = []
    labels: list[str] = []

    by_track: dict[str, list[dict]] = defaultdict(list)
    for input_value in args.input:
        input_path = Path(input_value)
        if not input_path.exists():
            raise FileNotFoundError(input_path)

        with input_path.open("r", encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                record = json.loads(line)
                by_track[str(record.get("track_id", "0"))].append(record)

    for track_id, frames in by_track.items():
        frames.sort(key=lambda item: item["timestamp_ms"])
        window = args.window
        stride = args.stride

        for start in range(0, max(0, len(frames) - window + 1), stride):
            chunk = frames[start : start + window]
            if len(chunk) < window:
                continue

            label_counts = Counter(item["label"] for item in chunk)
            label = label_counts.most_common(1)[0][0]

            data = np.array([item["keypoints"] for item in chunk], dtype=np.float32)
            sequences.append(data)
            labels.append(label)

    if not sequences:
        raise RuntimeError("No sequences built. Check input data.")

    label_list = sorted(set(labels))
    label_map = {name: idx for idx, name in enumerate(label_list)}
    y = np.array([label_map[label] for label in labels], dtype=np.int64)
    x = np.stack(sequences, axis=0)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(output_path, x=x, y=y, labels=label_list)


if __name__ == "__main__":
    main()
