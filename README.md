# Video AI Detect

Clean base for a scalable human action summary + fall detection system.

## Structure
- backend: FastAPI service and AI pipeline placeholders
- mobile: Flutter app skeleton

## Backend
1. Copy env file
   - Create backend/.env from backend/.env.example
2. Install deps
   - Python 3.11+ recommended
   - pip install -r backend/requirements.txt
   - pip install -r backend/requirements-ml.txt
3. Run API
   - uvicorn app.main:app --host 0.0.0.0 --port 8000

## Demo Mode (No Camera)
1. Enable demo mode in backend/.env
   - DEMO_MODE=true
2. Run API and connect from Flutter

## Real Camera Input
If you have a real camera connected to this machine, use webcam mode first:

1. Open backend/.env
2. Set:
   - CAMERA_SOURCE=webcam
   - WEBCAM_INDEX=0
   - DEMO_MODE=false
3. Start the backend from the backend folder:
   - uvicorn app.main:app --host 0.0.0.0 --port 8000
4. Check the status endpoint:
   - GET http://127.0.0.1:8000/api/status

If the webcam is not index 0, try 1, 2, or 3 until the camera opens.

## YOLOv11 Object Detection + Pose
The backend runs YOLOv11 for object tracking and YOLOv11 Pose for keypoints.

Default settings in `backend/.env`:
- `YOLO_MODEL_PATH=yolo11n.pt`
- `YOLO_POSE_MODEL_PATH=yolo11s-pose.pt`
- `YOLO_CONFIDENCE=0.35`
- `YOLO_POSE_CONFIDENCE=0.25`
- `YOLO_IOU=0.5`
- `YOLO_POSE_IOU=0.5`
- `YOLO_IMGSZ=640`
- `YOLO_MAX_DET=20`
- `YOLO_TRACKER=bytetrack.yaml`

If you want only certain COCO classes, set `YOLO_CLASSES` to comma-separated class ids.
Example: `0` for person, `1` for bicycle, `2` for car.

## ML Training Pipeline (Keypoints -> LSTM Action, XGBoost Fall)
1. Collect labeled keypoints for each action.
2. Build fixed-length sequences.
3. Train the LSTM action model.
4. Train the XGBoost fall classifier.

### 1) Collect keypoints
Run from the backend folder:

```bash
d:/flutter/video-ai-detect/.venv/Scripts/python.exe scripts/collect_keypoints.py --label walking --output data/raw/walking.jsonl --max-frames 3000
d:/flutter/video-ai-detect/.venv/Scripts/python.exe scripts/collect_keypoints.py --label sitting --output data/raw/sitting.jsonl --max-frames 3000
d:/flutter/video-ai-detect/.venv/Scripts/python.exe scripts/collect_keypoints.py --label lying --output data/raw/lying.jsonl --max-frames 3000
```

### 2) Build sequences

```bash
d:/flutter/video-ai-detect/.venv/Scripts/python.exe scripts/build_sequences.py --input data/raw/walking.jsonl data/raw/sitting.jsonl data/raw/lying.jsonl --output data/seq/actions.npz
```

### 3) Train action LSTM

```bash
d:/flutter/video-ai-detect/.venv/Scripts/python.exe scripts/train_action_lstm.py --data data/seq/actions.npz --output models/action_lstm.pt
```

### 4) Train fall XGBoost

```bash
d:/flutter/video-ai-detect/.venv/Scripts/python.exe scripts/train_fall_xgb.py --data data/seq/actions.npz --fall-label lying --output models/fall_xgb.json
```

## Real Input Sources (Camera or Video)
Set these in backend/.env:

- Webcam:
  - CAMERA_SOURCE=webcam
  - WEBCAM_INDEX=0
  - DEMO_MODE=false

- RTSP camera:
  - CAMERA_SOURCE=rtsp
  - RTSP_URL=rtsp://...
  - DEMO_MODE=false

- Video file:
  - CAMERA_SOURCE=file
  - VIDEO_FILE_PATH=D:/path/to/input.mp4
  - LOOP_VIDEO_FILE=true
  - DEMO_MODE=false

## MP4 Demo (No Training)
Run from the repo root so `PYTHONPATH` resolves `app` imports:

```bash
$env:PYTHONPATH="D:\\flutter\\video-ai-detect\\backend"; d:/flutter/video-ai-detect/.venv/Scripts/python.exe backend/scripts/run_demo_mp4.py --input "D:/flutter/video-ai-detect/backend/4MP PTZ Camera with Night Vision & Motion Detection _ CCTV Camera_ Video _ Sample Video Footage - (480p).mp4" --max-frames 60 --every 10
```

## Backend API (Time-Window First)
- GET /api/status
- GET /api/history?limit=100
- GET /api/summary?window_ms=5000
- GET /api/insights?window_ms=86400000
- POST /api/chat/query
   - Example payload:
      {
         "question": "Hoat dong nhieu nhat hom nay la gi?",
         "window_ms": 86400000
      }

## Realtime Channels
- WebSocket /api/ws
   - Legacy continuous status stream (for debugging/backward compatibility)
- WebSocket /api/ws/fall-alerts
   - Immediate fall alerts only

## Quick Backend Demo
1. Run API (from backend folder)
   - uvicorn app.main:app --host 0.0.0.0 --port 8000
2. Check current status
   - GET http://127.0.0.1:8000/api/status
3. Ask chat summary
   - POST http://127.0.0.1:8000/api/chat/query
   - body:
      {
         "question": "Hoat dong nhieu nhat hom nay?",
         "window_ms": 3600000
      }
4. Watch realtime data
   - python backend/scripts/test_ws.py --channel status --count 10
   - python backend/scripts/test_ws.py --channel fall --count 10

## Mobile
1. Install deps
   - flutter pub get
2. Run app
   - flutter run
3. Update websocket URL
   - Edit mobile/lib/features/fall_detection/fall_detection_screen.dart
   - For Android emulator, use ws://10.0.2.2:8000/api/ws
4. Generate models
   - dart run build_runner build --delete-conflicting-outputs

## Next steps
- Set RTSP_URL in backend/.env or switch CAMERA_SOURCE to webcam
- Replace action/fall heuristics with real models
- Add camera stream in Flutter and call backend API
