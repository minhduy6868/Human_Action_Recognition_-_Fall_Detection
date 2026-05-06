import argparse
import time

import cv2

from app.pipelines.action_summary import classify_action
from app.pipelines.fall_detection import FallDetector
from app.pipelines.keypoints import extract_keypoints_from_bbox, flatten_landmarks
from app.pipelines.object_detection import track_objects
from app.pipelines.pose_estimation import estimate_pose


def main() -> None:
    parser = argparse.ArgumentParser(description="Run YOLO+pose demo on MP4")
    parser.add_argument("--input", required=True, help="Input MP4 path")
    parser.add_argument("--max-frames", type=int, default=300)
    parser.add_argument("--every", type=int, default=10)
    args = parser.parse_args()

    try:
        import mediapipe as mp
    except ImportError as exc:
        raise RuntimeError("mediapipe is not installed") from exc

    cap = cv2.VideoCapture(args.input)
    if not cap.isOpened():
        raise RuntimeError(f"Failed to open video: {args.input}")

    pose_model = mp.solutions.pose.Pose(
        model_complexity=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    fall_detector = FallDetector()
    prev_center = None

    frame_index = 0
    start = time.time()
    while frame_index < args.max_frames:
        ret, frame = cap.read()
        if not ret:
            break

        frame_index += 1
        objects = track_objects(frame)
        persons = [det for det in objects if det.class_id == 0 or det.label == "person"]
        persons.sort(key=lambda det: det.confidence, reverse=True)

        primary_pose = None
        primary_track_id = "0"
        if persons:
            det = persons[0]
            primary_track_id = det.track_id or "0"
            primary_pose = extract_keypoints_from_bbox(
                frame,
                pose_model,
                (det.x1, det.y1, det.x2, det.y2),
            )

        if primary_pose is None:
            primary_pose = estimate_pose(frame, pose_model)

        action, confidence = classify_action(primary_pose, prev_center)
        if primary_pose and "center" in primary_pose:
            prev_center = primary_pose["center"]

        fall, fall_conf = fall_detector.update(primary_pose, action, int(time.time() * 1000))

        if frame_index % args.every == 0:
            print(
                f"frame={frame_index} persons={len(persons)} track={primary_track_id} "
                f"action={action} conf={confidence:.2f} fall={fall} fall_conf={fall_conf:.2f}"
            )

    cap.release()
    pose_model.close()
    elapsed = max(time.time() - start, 1e-6)
    fps = frame_index / elapsed
    print(f"done frames={frame_index} fps={fps:.2f}")


if __name__ == "__main__":
    main()
