# Video AI Detect - AI Summary Pipeline Design

Tài liệu này mô tả cách làm summary AI theo kiểu gọn, rõ, dễ code.

Mục tiêu:

- Summary dựa trên data detect, không dựa trên frame thô.
- LLM chỉ diễn đạt, không quyết định detection.
- REST API rõ ràng, auth rõ ràng, cache rõ ràng.

---

## 1. Mục tiêu của AI summary

AI summary không phải xử lý video thô. Nó chỉ làm việc trên dữ liệu đã chuẩn hóa từ backend, ví dụ:

- action theo thời gian.
- fall event.
- trạng thái người.
- timeline theo ngày.
- thống kê theo nhiều nguồn video.

Kết quả đầu ra cần:

- Tóm tắt ngắn gọn cho người dùng thường.
- Tóm tắt chi tiết cho VIP.
- Trả lời câu hỏi tự nhiên bằng tiếng Việt.
- Không làm ảnh hưởng đến tốc độ detect realtime.

---

## 2. Nguyên tắc thiết kế

### 2.1 Không gọi LLM theo từng frame

Sai:

- Mỗi frame detect xong lại gọi pipeline text-generation.

Đúng:

- Chỉ gọi summary khi:
  - user mở màn hình tóm tắt.
  - user đặt câu hỏi.
  - job nền tạo báo cáo định kỳ.

### 2.2 LLM chỉ nhận structured input

Input cho LLM nên là JSON đã lọc, ví dụ:

```json
{
  "window": "24h",
  "dominant_action": "walking",
  "action_segments": [
    { "action": "walking", "start": 0, "end": 600 },
    { "action": "sitting", "start": 600, "end": 1200 }
  ],
  "fall_detected": true,
  "fall_events": [
    { "timestamp": "2026-05-14T09:15:00Z", "confidence": 0.92 }
  ]
}
```

### 2.3 Realtime vẫn ưu tiên rule-based

Phần realtime nên dùng:

- rule-based summary.
- thống kê window.
- action smoothing.

LLM chỉ là lớp diễn đạt tự nhiên ở cuối.

---

## 3. Kiến trúc đề xuất

### 3.1 Pipeline tổng quát

```text
Frame capture
  -> Pose extraction
  -> Action/Fall detection
  -> Event store
  -> Timeline builder
  -> Summary aggregator
  -> Optional LLM narrator
  -> API response / WebSocket push
```

### 3.2 Các module nên có

- `capture_service`: lấy frame từ RTSP, webcam, file.
- `pose_service`: trích keypoints.
- `action_service`: phân loại action theo sequence.
- `fall_service`: phát hiện té ngã.
- `timeline_service`: gom action thành segment.
- `insight_service`: tạo thống kê theo window.
- `llm_service`: chuyển insight thành câu trả lời tự nhiên.

---

## 4. Dữ liệu đầu vào cho summary

### 4.1 Dữ liệu thời gian thực

Mỗi record realtime nên có tối thiểu:

```json
{
  "track_id": "person_01",
  "action": "walking",
  "confidence": 0.87,
  "fall": false,
  "fall_confidence": 0.1,
  "timestamp_ms": 1715688000000,
  "source_id": "camera_01"
}
```

### 4.2 Event store

Nên lưu các sự kiện:

- action change.
- fall detected.
- summary generated.
- user query.

### 4.3 Timeline segments

Timeline segment nên có:

```json
{
  "action": "sitting",
  "start_ms": 1715688000000,
  "end_ms": 1715688300000
}
```

---

## 5. Cách summary theo thời gian

### 5.1 Cửa sổ thời gian

Hệ thống nên hỗ trợ:

- 5 phút.
- 30 phút.
- 1 giờ.
- 1 ngày.
- nhiều ngày.

### 5.2 Cách gom dữ liệu

Với mỗi cửa sổ:

1. Lọc dữ liệu theo `from` và `to`.
2. Gộp action liên tục thành segment.
3. Tính tổng thời gian của từng action.
4. Lấy dominant action.
5. Đếm fall event.
6. Sinh insight.
7. Nếu cần, chuyển insight thành câu trả lời tự nhiên.

### 5.3 Output nên có

```json
{
  "window_ms": 86400000,
  "total_samples": 512,
  "dominant_action": "walking",
  "dominant_action_ratio": 0.61,
  "fall_detected": true,
  "segments": [
    { "action": "walking", "start_ms": 1715600000000, "end_ms": 1715603600000 },
    { "action": "sitting", "start_ms": 1715603600000, "end_ms": 1715607200000 }
  ]
}
```

---

## 6. Hướng dùng DeepSeek-R1-Zero

### 6.1 Có nên dùng không

Có thể dùng, nhưng chỉ dùng đúng vai trò:

- narrate summary.
- trả lời câu hỏi của user.
- chuyển insight thành câu tiếng Việt tự nhiên.

Không nên dùng cho:

- detection realtime.
- xử lý từng frame.
- thay thế logic fall/action.

### 6.2 Tại sao không nên gắn trực tiếp vào realtime

Nếu gọi kiểu:

```python
from transformers import pipeline

pipe = pipeline("text-generation", model="deepseek-ai/DeepSeek-R1-Zero", trust_remote_code=True)
```

thì sẽ gặp các rủi ro:

- latency cao.
- RAM/VRAM lớn.
- phụ thuộc model tải chậm.
- không ổn định trên máy yếu.
- dễ làm nghẽn backend inference.

### 6.3 Cách dùng đúng

Flow khuyến nghị:

1. Detect xong -> tạo insight JSON.
2. Cache insight theo window.
3. Nếu user hỏi, backend gọi LLM với summary JSON.
4. LLM chỉ viết lại thành câu trả lời thân thiện.
5. Trả kết quả ngay cho Flutter.

---

## 7. Prompt design cho LLM

### 7.1 Input prompt nên ngắn và có cấu trúc

Ví dụ:

```text
Bạn là trợ lý tóm tắt video an ninh.
Hãy trả lời bằng tiếng Việt, ngắn gọn, rõ ràng, đúng dữ liệu.

Dữ liệu đầu vào:
{
  "window": "24h",
  "dominant_action": "walking",
  "fall_detected": true,
  "fall_events": 2,
  "segments": [
    {"action": "walking", "duration_min": 70},
    {"action": "sitting", "duration_min": 40}
  ]
}

Yêu cầu:
- Tóm tắt ngắn 2-4 câu.
- Nếu có fall thì nêu rõ số lần và thời điểm gần nhất.
- Không bịa thêm thông tin.
```

### 7.2 Output mong muốn

Ví dụ phản hồi:

```text
Trong 24 giờ qua, hành động chiếm phần lớn là đi lại. Hệ thống ghi nhận 2 sự kiện té ngã, lần gần nhất xảy ra lúc 09:15. Ngoài ra có một khoảng thời gian ngồi kéo dài tương đối rõ.
```

### 7.3 Quy tắc chống hallucination

LLM phải bị ràng buộc:

- Chỉ trả lời từ data có sẵn.
- Không suy đoán video ngoài dữ liệu.
- Không tự tạo sự kiện fall nếu insight không có.
- Nếu thiếu dữ liệu thì nói rõ là chưa đủ dữ liệu.

---

## 8. API đề xuất cho summary AI

API summary phải theo RESTful style, auth bằng Bearer token.

### 8.1 Auth cho summary API

- Tất cả endpoint user-specific phải require `Authorization: Bearer <access_token>`.
- Backend lấy `user_id` từ token, không lấy từ body.
- Nếu token hết hạn, trả `401 Unauthorized`.

### 8.2 REST conventions

- Dùng `GET` cho đọc, `POST` cho tạo request summary, `PATCH` cho cập nhật cấu hình.
- Path là danh từ, không nhét action thừa nếu không cần.
- Response phải có `data`, `meta`, hoặc `error` nhất quán.

### 8.3 Summary theo câu hỏi

```http
POST /api/v1/chat/query
```

Payload:

```json
{
  "question": "Hôm nay có té ngã không?",
  "window_ms": 86400000
}
```

Response:

```json
{
  "answer": "Có phát hiện 1 lần té ngã...",
  "intent": "fall_check",
  "insight": {
    "fall_detected": true
  }
}
```

### 8.4 Summary theo ngày

```http
POST /api/v1/report/summary
```

Payload:

```json
{
  "window_ms": 86400000,
  "persist": true
}
```

### 8.5 Summary theo nhiều ngày

```http
POST /api/v1/summary/query
```

Payload:

```json
{
  "from": "2026-05-01T00:00:00Z",
  "to": "2026-05-14T23:59:59Z",
  "source_ids": ["camera_01", "camera_02"]
}
```

---

## 9. Phân quyền theo gói cho summary

### 9.1 Gói thường

- Có thể hỏi AI nhưng giới hạn số lượt.
- Chỉ summary theo 1 ngày hoặc theo phiên ngắn.
- Không cho query nhiều camera cùng lúc nếu muốn giữ chi phí thấp.

### 9.2 Gói VIP

- Không giới hạn lượt hỏi AI theo business rule.
- Summary theo ngày, tuần, custom range.
- Tổng hợp nhiều nguồn video.
- Ưu tiên cache và tốc độ phản hồi.

### 9.3 Enforcement

Backend cần chặn trước khi gọi LLM:

```python
if not policy.can_use_ai(user_id):
    raise HTTPException(status_code=402, detail="PLAN_LIMIT_REACHED")
```

---

## 10. Cache strategy

Để hệ thống mượt, nên cache theo ba tầng:

- Raw insight cache theo window.
- LLM answer cache theo question normalized.
- Daily summary cache theo source + date.

Ví dụ key:

```text
insight:source_01:2026-05-14:24h
answer:source_01:question_hash
daily:source_01:2026-05-14
```

Cache giúp:

- giảm chi phí LLM.
- giảm latency.
- giúp VIP có trải nghiệm nhanh hơn.

---

## 11. Performance targets

Mục tiêu kỹ thuật đề xuất:

- Realtime detection: dưới 1 giây.
- Summary API: 1-3 giây cho query thường.
- LLM answer: tối ưu dưới 5 giây.
- Không block stream khi summary đang chạy.

Các biện pháp:

- chạy summary trong worker/background task.
- dùng queue cho request nặng.
- tách thread/process giữa stream và summary.
- limit context size trước khi gọi LLM.

---

## 12. Nên làm gì trước

Ưu tiên triển khai theo thứ tự:

1. Chuẩn hóa insight JSON từ backend hiện tại.
2. Hoàn thiện summary API không dùng LLM trước.
3. Thêm cache và quota theo gói.
4. Bọc thêm LLM như lớp diễn đạt tự nhiên.
5. Đồng bộ UI Flutter hiển thị summary theo gói.

Đây là hướng an toàn nhất để giữ hệ thống realtime mượt mà.
