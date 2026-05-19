# Huấn luyện model phát hiện té ngã (Fall Detection)

Tài liệu ngắn mô tả nơi chứa mã liên quan đến model té ngã, cách training (nếu cần) và cách đưa model vào backend.

1) Vị trí các file chính
- [backend/app/pipelines/fall_model.py](backend/app/pipelines/fall_model.py#L1):
  - Chứa lớp `FallModel` (load/predict) và hàm `extract_fall_features()` để chuyển chuỗi keypoint thành vector đặc trưng.
- [backend/app/pipelines/fall_detection.py](backend/app/pipelines/fall_detection.py#L1):
  - Cài đặt rule-based `FallDetector` (dò ngã theo drop/aspect/velocity) — dùng khi `USE_ML_FALL=false`.
- [backend/models/fall_xgb.json](backend/models/fall_xgb.json#L1):
  - File model đã huấn luyện (xgboost) được load bởi `FallModel.load` theo `fall_model_path`.
- [backend/app/core/config.py](backend/app/core/config.py#L1):
  - Các thiết lập mặc định: `fall_model_path`, ngưỡng và thông số temporal.
- [backend/.env](backend/.env#L1) (hoặc `.env.example`):
  - Biến môi trường để bật/tắt ML fall: `USE_ML_FALL`, đường dẫn `FALL_MODEL_PATH` và các ngưỡng.
- [backend/app/services/stream_service.py](backend/app/services/stream_service.py#L1):
  - Đoạn gọi `FallModel.load()` và sử dụng `extract_fall_features()` để dự đoán fall trong pipeline realtime.

2) Hiểu luồng hoạt động (tóm tắt)
- Nếu `USE_ML_FALL=true` và đủ khung (frame sequence), pipeline sẽ gọi `extract_fall_features(sequence)` → `FallModel.predict(features)`.
- `FallModel.load()` dùng `xgboost.Booster().load_model(model_path)` để tải model từ file JSON/Binary.
- Nếu `USE_ML_FALL=false` (mặc định dự án), sẽ dùng `FallDetector` rule-based.

3) Nếu bạn muốn huấn luyện/re-huấn luyện model (hướng dẫn chung)
Prereqs: Python, xgboost, numpy, pandas (tuỳ script). Cài đặt ví dụ:

```powershell
pip install xgboost numpy pandas scikit-learn
```

- Tóm tắt quy trình:
  1. Chuẩn bị dataset: mỗi mẫu là một sequence các keypoint (x,y,visibility) theo khung; nhóm thành windows giống `action_window_frames`.
  2. Dùng cùng logic trong `extract_fall_features()` để chuyển mỗi sequence thành vector 10 chiều.
  3. Huấn luyện XGBoost (binary classification: fall / no-fall) trên feature vectors.
  4. Lưu model bằng `Booster.save_model("models/fall_xgb.json")`.

Ví dụ snippet để train và lưu model:

```python
import xgboost as xgb
import numpy as np
from sklearn.model_selection import train_test_split

# X: numpy array shape (N, 10); y: labels 0/1
X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42)
dtrain = xgb.DMatrix(X_train, label=y_train)
dval = xgb.DMatrix(X_val, label=y_val)
params = {"objective": "binary:logistic", "eval_metric": "logloss"}
bst = xgb.train(params, dtrain, num_boost_round=100, evals=[(dval, "val")])
bst.save_model("backend/models/fall_xgb.json")
```

4) Ghi chú và kiểm tra
- Kiểm tra `backend/app/pipelines/fall_model.py` để đảm bảo định dạng features khớp với dữ liệu huấn luyện (cùng thứ tự và chuẩn hoá nếu có).
- Nếu dùng GPU/CUDA, cài `xgboost` tương thích và cấu hình `MODEL_DEVICE` (lưu ý: `FallModel.load` dùng Booster.load_model, việc chọn device thường cấu hình lúc training).
- File model hiện có: [backend/models/fall_xgb.json](backend/models/fall_xgb.json#L1). Nếu file rỗng hoặc chưa có, cần lưu model sau khi train như trên.

5) Bật ML fall trong runtime
- Trong `.env` hoặc biến môi trường, đặt `USE_ML_FALL=true` và `FALL_MODEL_PATH=models/fall_xgb.json`.
- Khởi động backend như bình thường; pipeline sẽ tự load model khi cần.

6) Tài liệu tham khảo trong repo
- Test: [tests/test_fall_model_predict.py](tests/test_fall_model_predict.py#L1) và [tests/test_fall_detector.py](tests/test_fall_detector.py#L1) để xem ví dụ sử dụng và dữ liệu kiểm thử.

---
Nếu bạn muốn, mình có thể:
- Viết script training đầy đủ (ví dụ `backend/scripts/train_fall_xgb.py`) dựa trên `extract_fall_features()`;
- Hoàn thiện một notebook huấn luyện hoặc thêm ví dụ dataset mô phỏng.

Nói mình biết bạn muốn bước tiếp nào nhé.
