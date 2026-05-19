# Huấn dẫn: Tải và huấn luyện lại model phát hiện té ngã (fall_xgb.json)

Mục tiêu: mô tả quy trình tải dữ liệu, huấn luyện lại model XGBoost dùng tính năng từ `extract_fall_features()` và cách sử dụng file model JSON (`backend/models/fall_xgb.json`) trong runtime.

1) Tóm tắt nhanh
- Script huấn luyện có sẵn: `backend/scripts/train_fall_xgb_from_kaggle_csv.py` (có tuỳ chọn `--download` cho dataset Kaggle `payutch/fall-video-dataset`).
- Model đã được lưu tại: `backend/models/fall_xgb.json` — có thể tải lại bằng `FallModel.load(path)` lúc runtime.

2) Chuẩn bị môi trường
- Tạo virtualenv và cài phụ thuộc ML:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend/requirements-ml.txt
```

Ghi chú: nếu dùng GPU, cài phiên bản `torch` có CUDA tương thích theo hướng dẫn trong `backend/requirements-ml.txt`.

3) Tải dataset Kaggle (tuỳ chọn)
- Cách nhanh (dùng `kagglehub` tích hợp trong script):

```powershell
python backend/scripts/train_fall_xgb_from_kaggle_csv.py --download
```

Sau khi tải xong, script sẽ in ra đường dẫn unzipped; bạn có thể chạy tiếp với `--data_root "<path>"`.

Nếu bạn đã tải thủ công và giải nén dataset (ví dụ từ https://www.kaggle.com/datasets/payutch/fall-video-dataset), trỏ `--data_root` tới thư mục gốc của dataset:

```powershell
python backend/scripts/train_fall_xgb_from_kaggle_csv.py --data_root "D:/datasets/fall-video-dataset"
```

4) Huấn luyện (từ CSV keypoints)
- Script kỳ vọng dữ liệu Keypoints CSV theo cấu trúc `Keypoints_CSV/*.csv` như trong Kaggle archive. Ví dụ chạy đầy đủ:

```powershell
python backend/scripts/train_fall_xgb_from_kaggle_csv.py --data_root "D:/datasets/fall-video-dataset" --out backend/models/fall_xgb.json
```

Tuỳ chọn hữu ích:
- `--window`: số khung mỗi sample (mặc định 30, khớp `ACTION_WINDOW_FRAMES`).
- `--stride`: bước trượt cửa sổ trên clip dài.
- `--max_csv_per_class`: giới hạn file CSV để chạy nhanh thử nghiệm.
- `--synthetic`: tạo dữ liệu mô phỏng nội bộ (dùng cho smoke-test, không chính xác thực tế).

5) Cách lưu model
- Script đã lưu model bằng `booster.save_model(str(out_path))` ở dạng JSON/binary tương thích `xgboost.Booster.load_model()`.

6) Kiểm tra model sau khi train
- Khởi động backend hoặc dùng Python nhỏ để load và test:

```python
from backend.app.pipelines.fall_model import FallModel, extract_fall_features
fm = FallModel.load('backend/models/fall_xgb.json')
features = extract_fall_features(sample_sequence)
score = fm.predict(features)
print('fall score:', score)
```

7) Tương thích dữ liệu huấn luyện và runtime
- RẤT QUAN TRỌNG: khi tạo feature vectors để train, phải dùng chính xác cùng logic và thứ tự trả về của `extract_fall_features()` (10 chiều):
  1. `drop_max`
  2. `drop_mean`
  3. `drop_std`
  4. `aspect_max`
  5. `aspect_mean`
  6. `height_min`
  7. `height_mean`
  8. `center_last`
  9. `center_mean`
 10. `lying_ratio`

- Ngoài ra đảm bảo `keypoint_visibility_threshold` dùng lúc trích keypoints (xem `backend/app/core/config.py`) khớp với giá trị khi tạo CSV keypoints.

8) Thực hành nhanh (ví dụ chạy local, train nhanh bằng dữ liệu mô phỏng)

```powershell
# Kiểm tra nhanh với dữ liệu synthetic
python backend/scripts/train_fall_xgb_from_kaggle_csv.py --synthetic --synthetic_samples 1000 --out backend/models/fall_xgb_synth.json

# Sau đó test load
python -c "from backend.app.pipelines.fall_model import FallModel; fm=FallModel.load('backend/models/fall_xgb_synth.json'); print('loaded', fm)"
```

9) Ghi chú về nguồn dữ liệu
- Script có tham chiếu tới dataset Kaggle `payutch/fall-video-dataset` (https://www.kaggle.com/datasets/payutch/fall-video-dataset). Nếu bạn đã từng chạy `--download` hoặc copy dữ liệu từ đó, rất có khả năng model hiện có trong `backend/models/fall_xgb.json` được huấn luyện từ dataset đó (xem lịch sử commit trong repo).

10) Muốn mình làm tiếp
- Mình có thể:
  - Khôi phục/ghi lại script `backend/scripts/train_fall_xgb_from_kaggle_csv.py` vào workspace nếu nó chưa tồn tại (script đã nằm trong git history).
  - Viết notebook huấn luyện chi tiết (keypoint extraction → features → train → eval).
  - Tạo unit test mẫu để kiểm tra `FallModel.predict()` với dữ liệu mô phỏng.

Chỉ bảo mình muốn bước nào tiếp theo.