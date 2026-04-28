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

## Streaming Endpoints
- GET /api/status
- GET /api/history?limit=100
- GET /api/summary?window_ms=5000
- WebSocket /api/ws

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
