import argparse
from pathlib import Path

import numpy as np

from app.pipelines.fall_model import extract_fall_features


def main() -> None:
    parser = argparse.ArgumentParser(description="Train XGBoost fall detector")
    parser.add_argument("--data", required=True, help="Input NPZ from build_sequences")
    parser.add_argument("--fall-label", default="fall", help="Label name for fall samples")
    parser.add_argument("--output", required=True, help="Output model path")
    args = parser.parse_args()

    import xgboost as xgb

    data = np.load(args.data, allow_pickle=True)
    x = data["x"]
    y = data["y"]
    labels = data["labels"].tolist()

    if args.fall_label not in labels:
        raise RuntimeError(f"Label '{args.fall_label}' not found in dataset")

    fall_index = labels.index(args.fall_label)
    y_binary = (y == fall_index).astype(np.int32)

    features = np.array([extract_fall_features(seq.tolist()) for seq in x], dtype=np.float32)

    dtrain = xgb.DMatrix(features, label=y_binary)
    params = {
        "max_depth": 4,
        "eta": 0.1,
        "subsample": 0.9,
        "colsample_bytree": 0.9,
        "objective": "binary:logistic",
        "eval_metric": "logloss",
    }

    booster = xgb.train(params, dtrain, num_boost_round=200)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    booster.save_model(output_path)


if __name__ == "__main__":
    main()
