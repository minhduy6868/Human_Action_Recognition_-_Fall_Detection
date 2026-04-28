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

## Streaming Endpoints
- GET /api/status
- GET /api/history?limit=100
- WebSocket /api/ws

## Mobile
1. Install deps
   - flutter pub get
2. Run app
   - flutter run
3. Update websocket URL
   - Edit mobile/lib/features/fall_detection/fall_detection_screen.dart
   - For Android emulator, use ws://10.0.2.2:8000/api/ws

## Next steps
- Set RTSP_URL in backend/.env or switch CAMERA_SOURCE to webcam
- Replace action/fall heuristics with real models
- Add camera stream in Flutter and call backend API
