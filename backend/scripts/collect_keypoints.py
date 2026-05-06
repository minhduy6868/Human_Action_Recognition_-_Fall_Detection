import argparse
import json
import time
from pathlib import Path

import cv2

from app.core.config import get_settings
from app.pipelines.keypoints import extract_keypoints_from_bbox, flatten_landmarks
from app.pipelines.object_detection import track_objects


def open_capture():
    settings = get_settings()
    source = settings.camera_source.lower()
    if source == "webcam":
        return cv2.VideoCapture(settings.webcam_index)
    if source == "file":
        return cv2.VideoCapture(settings.video_file_path)
    if source == "rtsp" and settings.rtsp_url:
        return cv2.VideoCapture(settings.rtsp_url)
    raise RuntimeError(f"Unsupported camera_source: {source}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Collect keypoints for action training")
    parser.add_argument("--label", required=True, help="Action label for this recording")
    parser.add_argument("--output", required=True, help="Output JSONL path")
    parser.add_argument("--max-frames", type=int, default=2000)
    parser.add_argument("--skip", type=int, default=0)
    args = parser.parse_args()

    settings = get_settings()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        import mediapipe as mp
    except ImportError as exc:
        raise RuntimeError("mediapipe is not installed") from exc

    cap = open_capture()
    if not cap.isOpened():
        raise RuntimeError("Failed to open capture device")

    pose_model = mp.solutions.pose.Pose(
        model_complexity=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    frame_index = 0
    with output_path.open("w", encoding="utf-8") as f:
        while frame_index < args.max_frames:
            ret, frame = cap.read()
            if not ret:
                break

            frame_index += 1
            if args.skip > 0 and frame_index % (args.skip + 1) != 0:
                continue

            ts_ms = int(time.time() * 1000)
            objects = track_objects(frame)
            persons = [det for det in objects if det.class_id == 0 or det.label == "person"]

            for det in persons:
                pose = extract_keypoints_from_bbox(
                    frame,
                    pose_model,
                    (det.x1, det.y1, det.x2, det.y2),
                )
                if not pose:
                    continue

                record = {
                    "timestamp_ms": ts_ms,
                    "track_id": det.track_id or "0",
                    "label": args.label,
                    "bbox": [det.x1, det.y1, det.x2, det.y2],
                    "keypoints": flatten_landmarks(pose["landmarks"]),
                }
                f.write(json.dumps(record) + "\n")

    cap.release()
    pose_model.close()


if __name__ == "__main__":
    main()
