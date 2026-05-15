# Video AI Detect — Human Action & Fall Detection

A realtime AI system that captures video, detects human poses, recognizes actions (standing, sitting, walking, lying, crouching, running), detects falls, identifies clothing colors, and tracks multiple people simultaneously. Includes a Python FastAPI backend and Flutter mobile/desktop frontend.

**Status**: ✅ Backend running with enhanced detection | ✅ Flutter app deployable | ✅ Multi-person tracking | ✅ Auth + Postgres logs

---

## System Overview

- Backend: FastAPI + JWT auth + WebSocket realtime
- Database: Postgres for users, sources, logs, alerts, reports, chat history
- AI: pose estimation + action detection + fall detection + event reasoning
- Mobile: Flutter client (realtime + REST)

## System Flow

1. Capture frames from RTSP/webcam/file
2. Detect people + objects (YOLO)
3. Pose estimation per person
4. Action recognition (sequence + smoothing)
5. Fall detection (rule-based or ML fallback)
6. Event reasoning (crowd/loiter/abandoned)
7. Persist logs + alerts to Postgres
8. Stream realtime via WebSocket + MJPEG

---

## AI Pipeline Overview

1. Capture frames (RTSP/webcam/file)
2. Pose estimation per person
3. Action classification (sequence + smoothing)
4. Fall detection (rule-based or ML fallback)
5. Event reasoning (loitering, crowd, abandoned objects)
6. Log to Postgres (frame logs + people/objects JSON)
7. Realtime status via WebSocket + REST

---

## AI System Details

### Models and Components

- **Detection/Tracking**: Ultralytics YOLO (default weights: `yolo11n.pt`) for people + objects with tracking IDs.
- **Pose Estimation**: YOLO pose model (default weights: `yolo11s-pose.pt`) for keypoints.
- **Action Recognition**:
  - Rule-based classifier (knee angles, bbox aspect ratio, motion) for realtime inference.
  - Optional LSTM model (config: `USE_ML_ACTION=true`, `ACTION_MODEL_PATH=...`).
- **Fall Detection**:
  - Rule-based detector (drop + velocity + aspect ratio + confirmation window).
  - Optional ML fallback using XGBoost (config: `USE_ML_FALL=true`, `FALL_MODEL_PATH=...`).
- **Event Reasoning**: Crowd, loitering, suspicious movement, abandoned object rules.
- **Auxiliary**: Clothing color detection + simple person identification by visual features.

### Realtime Decision Logic

- **No single-frame decisions**: actions and falls are inferred over temporal windows.
- **Smoothing**: action predictions are averaged over recent frames before emitting.
- **Fallback strategy**: if ML models are unavailable, rule-based logic is used.
- **Performance-first**: adaptive frame skip to maintain target FPS.

### Key Data Outputs

- `status` includes: `action`, `confidence`, `fall`, `fall_confidence`, `track_id`.
- `people[]` includes per-person action, bbox, clothing, fall status.
- `objects[]` includes all detected objects + class labels + tracking IDs.

### AI Configuration Knobs (backend/.env)

- `YOLO_MODEL_PATH`, `YOLO_POSE_MODEL_PATH`
- `YOLO_CONFIDENCE`, `YOLO_IOU`, `YOLO_IMG_SIZE`, `YOLO_MAX_DET`
- `KEYPOINT_VISIBILITY_THRESHOLD`, `POSE_MATCH_MIN_IOU`
- `USE_ML_ACTION`, `ACTION_MODEL_PATH`, `ACTION_WINDOW_FRAMES`, `ACTION_SMOOTH_WINDOW`
- `USE_ML_FALL`, `FALL_MODEL_PATH`, `FALL_DROP_THRESHOLD`, `FALL_ASPECT_THRESHOLD`, `FALL_CONFIRM_MS`

---

## Database Overview (Postgres)

Core tables:
- `users`: accounts, roles, plans
- `refresh_tokens`: refresh token storage
- `source_connections`: per-user camera sources
- `alerts`: alerts from rule/event detection
- `summary_reports`: cached summaries
- `detection_logs`: realtime logs (people/objects JSON)
- `chat_history`: AI chat summary history

Retention:
- `detection_logs` cleanup by `LOG_RETENTION_DAYS`
- `chat_history` cleanup by `CHAT_HISTORY_RETENTION_DAYS`

## 🎯 Key Features (Updated 2026-05-14)

- **Multi-person Detection**: Track multiple people simultaneously with individual actions
- **6 Action Types**: Standing, Walking, Running, Sitting, Crouching, Lying
- **Clothing Recognition**: Automatic detection of upper/lower clothing colors
- **Person Identification**: Visual feature-based person tracking across frames
- **Object Detection**: Detect and classify 80+ object types (chairs, tables, bottles, etc.)
- **Fall Detection**: Real-time fall detection with confidence scoring
- **Enhanced Performance**: 18-20 FPS processing, 15 FPS MJPEG streaming
- **WebSocket Updates**: Real-time status updates every 250ms

---

## Quick Start (5 minutes)

### Prerequisites
- **Python 3.11+** with pip
- **Flutter SDK** (for mobile app)
- **Git**
- Connected mobile device on same WiFi (for testing)

---

## 🖥️ Backend Setup

### 1. Setup Python Environment

```powershell
# From repository root
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r backend/requirements.txt
pip install -r backend/requirements-ml.txt
```

**Expected**: All packages installed, including `fastapi`, `torch`, `ultralytics`, `opencv-python`.

### 2. Configure Backend (.env)

The `.env` file is pre-configured to use **fall5.mp4**:

```
CAMERA_SOURCE=file
VIDEO_FILE_PATH=d:/flutter/video-ai-detect/backend/fall5.mp4
LOOP_VIDEO_FILE=true
ENABLE_STREAM=true
```

To use a different video or camera:
```powershell
# Edit backend\.env manually
# CAMERA_SOURCE options: file | webcam | rtsp | http | demo
# WEBCAM_INDEX=0  (for webcam)
# RTSP_URL=rtsp://... (for IP cameras)
```

### 3. Run Backend

```powershell
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Expected Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
2026-05-14 12:05:27,391 INFO app.services.stream_service Video capture opened successfully, starting pose estimation
```

✅ **Backend is now:**
- Processing fall5.mp4 in real-time
- Detecting poses and actions
- Streaming WebSocket data on `ws://YOUR_PC_IP:8000/api/v1/ws`

### Available Endpoints (v1)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/api/v1/health` | GET | API health |
| `/api/v1/auth/login` | POST | Login (JWT) |
| `/api/v1/auth/refresh` | POST | Refresh token |
| `/api/v1/auth/logout` | POST | Logout (revoke refresh) |
| `/api/v1/auth/me` | GET | Current user |
| `/api/v1/status` | GET | Current detection status |
| `/api/v1/history` | GET | Detection history (RAM) |
| `/api/v1/logs` | GET | Detection logs (Postgres) |
| `/api/v1/logs/{id}` | GET | Log detail (people/objects JSON) |
| `/api/v1/people` | GET | Current people list |
| `/api/v1/people/{track_id}` | GET | Person detail |
| `/api/v1/objects` | GET | Current objects list |
| `/api/v1/alerts` | GET | Alerts (RAM) |
| `/api/v1/alerts/after` | GET | Alerts after id |
| `/api/v1/fall-events` | GET | Fall events (RAM) |
| `/api/v1/fall-events/after` | GET | Fall events after id |
| `/api/v1/chat/query` | POST | AI summary query |
| `/api/v1/chat/history` | GET | Chat history |
| `/api/v1/summary/query` | POST | Summary range query |
| `/api/v1/report/summary` | POST | Summary report |
| `/api/v1/sources` | GET/POST | Source list/create |
| `/api/v1/sources/{id}` | GET/PATCH/DELETE | Source detail/update/delete |
| `/api/v1/sources/{id}/activate` | POST | Activate source |
| `/api/v1/streams/start` | POST | Start stream by source |
| `/api/v1/streams/stop` | POST | Stop stream by source |
| `/api/v1/streams` | GET | Active streams |
| `/api/v1/streams/{id}/status` | GET | Stream status |
| `/api/v1/stream/mjpeg` | GET | MJPEG (default) |
| `/api/v1/streams/{id}/mjpeg` | GET | MJPEG by source |
| `/api/v1/ws` | WS | Realtime stream |

**Response format**: all v1 endpoints return `{ data, meta }` or `{ error, meta }`.

---

## 📱 Mobile App Setup

### 1. Get Your PC IP Address

Open a new PowerShell window:

```powershell
ipconfig | findstr /i "IPv4"
```

**Find your WiFi adapter IP** (e.g., `192.168.1.11`)

### 2. Update App Configuration

The app is pre-configured to connect to `192.168.1.11:8000`. If your IP is different, update:

**File**: `mobile/lib/core/app_config.dart`

```dart
switch (defaultTargetPlatform) {
  case TargetPlatform.android:
    return 'YOUR_PC_IP:8000';  // ← Change this
  case TargetPlatform.iOS:
    return 'YOUR_PC_IP:8000';  // ← Change this
  default:
    return 'YOUR_PC_IP:8000';  // ← Change this
}
```

### 3. Run Flutter App

**Ensure your phone is on the same WiFi as your PC**, then:

```powershell
cd mobile
flutter pub get
flutter run
```

Select your device when prompted. The app will:
- ✅ Connect to WebSocket `ws://YOUR_PC_IP:8000/api/v1/ws`
- ✅ Display real-time action (standing, walking, sitting, lying)
- ✅ Show fall detection alerts
- ✅ Display confidence scores

---

## 🎬 Demo Scenarios

### Scenario 1: Video File (fall5.mp4)

**Already configured!** Just run backend and app together:

```powershell
# Terminal 1: Backend
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# Terminal 2: Mobile app
cd mobile
flutter run
```

### Scenario 2: Webcam

Update `backend/.env`:
```
CAMERA_SOURCE=webcam
WEBCAM_INDEX=0
```

Then restart backend and app.

### Scenario 3: RTSP Camera (IP Camera)

Update `backend/.env`:
```
CAMERA_SOURCE=rtsp
RTSP_URL=rtsp://user:password@192.168.1.100:554/stream
```

Then restart backend and app.

---

## 🧪 Testing

### Test Backend Health

```powershell
curl http://127.0.0.1:8000/health
# Expected: {"status":"ok"}
```

### Test WebSocket Connection

```powershell
# From repository root:
.venv\Scripts\python.exe backend/scripts/test_ws.py --channel status --count 10
```

### Test Action Detection

Run the demo script:

```powershell
$env:PYTHONPATH = (Get-Location)\backend
.venv\Scripts\python.exe backend/scripts/run_demo_mp4.py --input backend/fall5.mp4 --max-frames 600 --every 10
```

---

## 📋 Configuration Reference

### Environment Variables (backend/.env)

| Variable | Options | Default | Purpose |
|----------|---------|---------|---------|
| `CAMERA_SOURCE` | `file`, `webcam`, `rtsp`, `http`, `mjpeg` | `rtsp` | Input source |
| `VIDEO_FILE_PATH` | Path string | (empty) | Path to MP4 file |
| `WEBCAM_INDEX` | Integer | `0` | Webcam device index |
| `RTSP_URL` | URL string | (empty) | RTSP stream URL |
| `LOOP_VIDEO_FILE` | `true`/`false` | `false` | Loop video when done |
| `ENABLE_STREAM` | `true`/`false` | `true` | Enable processing |
| `FRAME_SKIP` | Integer | `1` | Process every N frames |
| `TARGET_FPS` | Integer | `15` | Target FPS for output |
| `FALL_DROP_THRESHOLD` | Float | `0.18` | Fall detection threshold |
| `FALL_CONFIRM_MS` | Integer | `1500` | Ms to confirm fall |

---

## 🏗️ Project Structure

```
video-ai-detect/
├── backend/
│   ├── app/
│   │   ├── main.py                 # FastAPI app entry
│   │   ├── api/routes.py           # API endpoints
│   │   ├── services/
│   │   │   ├── stream_service.py   # Video processing loop
│   │   │   ├── inference_service.py # AI inference
│   │   │   └── alert_engine.py     # Fall alerts
│   │   ├── pipelines/
│   │   │   ├── pose_estimation.py  # MediaPipe/YOLO pose
│   │   │   ├── fall_detection.py   # Fall detection logic
│   │   │   └── action_model.py     # Action classification
│   │   └── core/
│   │       ├── config.py           # Settings from .env
│   │       └── logging.py          # Logging setup
│   ├── .env                         # Configuration file
│   ├── requirements.txt             # API dependencies
│   ├── requirements-ml.txt          # ML dependencies
│   ├── fall5.mp4                    # Test video
│   └── scripts/
│       ├── run_demo_mp4.py          # Demo script
│       └── test_ws.py               # WebSocket test
├── mobile/
│   ├── lib/
│   │   ├── main.dart                # App entry
│   │   ├── core/app_config.dart     # Backend URL config
│   │   ├── services/
│   │   │   ├── realtime_stream.dart # WebSocket connection
│   │   │   └── api_client.dart      # API client
│   │   ├── features/                # App screens & features
│   │   └── models/                  # Data models
│   ├── pubspec.yaml                 # Flutter dependencies
│   └── ...
└── README.md                        # This file
```

---

## 🐛 Troubleshooting

### Backend won't start (ModuleNotFoundError)

Ensure you're in the `backend/` directory when running uvicorn:

```powershell
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### App can't connect to backend

1. **Check PC IP matches** in `mobile/lib/core/app_config.dart`
2. **Verify WiFi**: Phone and PC on same network?
3. **Check firewall**: Allow Python/Uvicorn traffic on port 8000
4. **Test connectivity**:
   ```powershell
   # From phone terminal or desktop:
   ping YOUR_PC_IP
   ```

### Fall detection not triggering

- Ensure `FALL_DROP_THRESHOLD`, `FALL_ASPECT_THRESHOLD` are tuned for your scenario
- Check that pose estimation is running (log messages show keypoints)
- For `fall5.mp4`, falls should be detected automatically

### Performance issues (low FPS)

- Reduce `YOLO_IMGSZ` from 640 to 416
- Increase `FRAME_SKIP` to 2 or 3
- Disable unused features (action model, fall model if using rule-based)

---

## 🚀 Deployment

### Production Backend

Use a process manager instead of `--reload`:

```bash
# Install supervisor or systemd
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
```

### Production Mobile

Build APK for Android:

```powershell
flutter build apk --release
```

Or AAB for Google Play:

```powershell
flutter build appbundle --release
```

---

## 📚 Further Reading

- **MediaPipe Pose**: https://mediapipe.dev/
- **YOLO**: https://github.com/ultralytics/ultralytics
- **FastAPI**: https://fastapi.tiangolo.com/
- **Flutter**: https://flutter.dev/

---

## 📝 License & Contributing

This project is open for development and testing. See `LICENSE` for details.

---

## ✅ Verified Setup

**Last tested**: May 14, 2026 | **Status**: ✅ Working

- ✅ Backend: Python 3.11, FastAPI 0.115, Uvicorn running on 0.0.0.0:8000
- ✅ ML Pipeline: Ultralytics 8.3, torch 2.4.1, opencv 4.10
- ✅ Mobile: Flutter 3.x, WebSocket connectivity
- ✅ Test Video: fall5.mp4 processing in real-time

