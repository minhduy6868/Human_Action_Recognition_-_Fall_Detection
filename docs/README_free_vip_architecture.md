# Video AI Detect - Free/VIP Product Architecture

Tài liệu này là bản spec ngắn và đủ rõ để code sau này bám theo ngay.

Mục tiêu:

- Realtime detection ở backend Python.
- Flutter chỉ hiển thị và gọi API.
- Auth chuẩn, RESTful chuẩn, có quota theo gói.
- Gói thường và VIP khác nhau rõ ràng, không nhập nhằng.

---

## 1. Mục tiêu sản phẩm

Hệ thống chỉ cần 4 việc chính:

1. Nhận video từ CCTV, RTSP, webcam hoặc file.
2. Detect action/fall ở backend.
3. Tóm tắt theo timeline khi user hỏi.
4. Giới hạn tính năng theo gói.

Nguyên tắc bắt buộc:

- Flutter không xử lý AI.
- Backend quyết định quyền truy cập.
- Không dùng single-frame decision.
- Không để client tự giả lập quota.

---

## 2. Phạm vi hiện tại của hệ thống

Hiện tại đã có:

- FastAPI backend.
- Realtime status qua WebSocket.
- History, summary, chat query.
- Flutter có dark/light mode và vi/en.

Chưa đủ để ra sản phẩm chuẩn:

- Auth login/token/refresh.
- Plan free/vip.
- Quota hỏi AI.
- Quản lý source theo user.
- REST API chuẩn hoá response/error.

---

## 3. Đề xuất phân tầng kiến trúc

### 3.1 Client layer

Flutter chỉ chịu trách nhiệm:

- Đăng nhập.
- Hiển thị gói hiện tại.
- Thêm, chọn, bật/tắt nguồn video.
- Xem livestream / trạng thái realtime.
- Gửi câu hỏi AI và hiển thị kết quả summary.
- Hiển thị cảnh báo fall ngay lập tức.
- Chuyển ngôn ngữ và theme.

Flutter không được:

- Chạy inference từ frame.
- Tự summary bằng mô hình local.
- Tự quyết định quota.

### 3.2 Backend API layer

FastAPI chịu trách nhiệm:

- Auth token / session.
- Kiểm tra gói thường hay VIP.
- Quản lý source video của từng user.
- Trả trạng thái realtime qua REST và WebSocket.
- Chạy detection, summary, reasoning.
- Lưu lịch sử và báo cáo.

### 3.3 AI pipeline layer

Pipeline backend nên chia rõ:

- Capture service: đọc stream từ file, RTSP, webcam.
- Pose service: trích keypoint.
- Action service: nhận sequence nhiều frame.
- Fall service: rule-based hoặc ML fallback.
- Summary service: gom timeline, thống kê theo ngày.
- LLM service: tạo câu trả lời tự nhiên từ data đã chuẩn hóa.

### 3.4 Storage layer

Nên có 4 nhóm lưu trữ:

- User account và subscription.
- Camera/source registry.
- Event history: action, fall, alert.
- Summary cache: ngày, tuần, tháng.

---

## 4. Gói thường và gói VIP

### 4.1 Gói thường

Chức năng:

- Xem realtime status.
- Xem cảnh báo fall.
- Hỏi AI có giới hạn.
- Chỉ được 1 source active.
- Có thể đổi source, nhưng source cũ phải tắt ngay.

Giới hạn đề xuất:

- `max_active_sources = 1`
- `max_sources = 1` (tổng số nguồn được tạo/lưu)
- `daily_ai_queries = 10` hoặc `20`
- `history_window = 24h`
- `summary_window = 24h`.

### 4.2 Gói VIP

Chức năng:

- Tất cả quyền của gói thường.
- Thêm nhiều nguồn video.
- Hỏi AI không giới hạn.
- Tóm tắt theo ngày, nhiều ngày, khoảng thời gian tùy chọn.
- Lưu lịch sử dài hơn.
- Ưu tiên xử lý / cache summary.

Giới hạn đề xuất:

- `max_active_sources >= 5` hoặc không giới hạn có kiểm soát.
- `max_sources >= 5` hoặc không giới hạn có kiểm soát.
- `daily_ai_queries = unlimited` nhưng vẫn rate-limit kỹ thuật.
- `history_window = 30d`, `90d`, hoặc cấu hình theo plan.

### 4.3 Quy tắc xử lý gói

Quy tắc phải nằm ở backend:

- Client gửi request với `user_id` hoặc access token.
- Backend resolve subscription trước khi xử lý.
- Nếu vượt quota, backend trả lỗi chuẩn hóa:

```json
{
  "detail": "AI query limit reached for current plan",
  "code": "PLAN_LIMIT_REACHED",
  "upgrade_required": true
}
```

---

## 5. Auth chuẩn

Auth phải theo kiểu chuẩn, dễ mở rộng, không hardcode logic trong Flutter.

### 5.1 Mô hình khuyến nghị

- Access token: JWT ngắn hạn.
- Refresh token: dài hạn, có thể revoke.
- Password hash: bcrypt hoặc argon2.
- Role: `user`, `admin`.
- Plan: `free`, `vip`.

### 5.2 Luồng đăng nhập

1. User gửi email/password.
2. Backend verify credentials.
3. Backend trả access token + refresh token.
4. Flutter lưu token an toàn.
5. Mọi request sau đó dùng `Authorization: Bearer <token>`.

### 5.3 Luồng refresh

1. Access token hết hạn.
2. Flutter gọi refresh endpoint.
3. Backend validate refresh token.
4. Backend trả access token mới.

### 5.4 Quy tắc auth

- Không nhét logic plan vào client.
- Không để endpoint không xác thực nếu endpoint đó liên quan dữ liệu user.
- Không dùng session cookie kiểu web nếu app mobile là chính.
- Luôn kiểm tra `user_id` từ token, không nhận từ body nếu không cần.

---

## 6. Quản lý nguồn video

### 6.1 Nguồn hợp lệ

Hệ thống nên hỗ trợ:

- RTSP URL.
- Webcam local.
- File video.
- HTTP/MJPEG stream.

### 6.2 Hành vi theo gói

Gói thường:

- Chỉ 1 nguồn active.
- Khi thêm nguồn mới thì phải replace nguồn hiện tại.
- Không cho tạo/lưu quá 1 nguồn (max_sources = 1).
- Có thể đổi nguồn nhưng luôn chỉ có 1 nguồn active.

Gói VIP:

- Nhiều nguồn được lưu.
- Có thể chạy đa camera nếu hạ tầng đủ.
- Cho phép nhiều nguồn active cùng lúc (theo giới hạn gói).
- Có thể schedule summary theo nguồn hoặc tổng hợp liên nguồn.

### 6.3 API đề xuất

```http
GET    /api/sources
POST   /api/sources
PATCH  /api/sources/{source_id}
DELETE /api/sources/{source_id}
POST   /api/sources/{source_id}/activate
```

Payload thêm nguồn:

```json
{
  "name": "CCTV Quầy lễ tân",
  "type": "rtsp",
  "url": "rtsp://user:pass@192.168.1.10:554/stream",
  "enabled": true
}
```

### 6.4 UI gợi ý

Màn hình nguồn video nên có:

- Danh sách nguồn.
- Trạng thái active/inactive.
- Nút thêm nguồn.
- Label gói hiện tại và giới hạn còn lại.
- Cảnh báo khi user của gói thường thêm nguồn thứ 2.

---

## 7. Subscription và dữ liệu

### 7.1 Bảng dữ liệu đề xuất

`users`

- `id`
- `email`
- `name`
- `password_hash` hoặc provider auth id
- `created_at`

`subscriptions`

- `user_id`
- `plan_type` = `free` | `vip`
- `status`
- `expires_at`
- `ai_query_limit_daily`
- `max_sources`
- `history_retention_days`

`source_connections`

- `id`
- `user_id`
- `source_type`
- `source_url`
- `is_active`
- `last_seen_at`

`ai_query_logs`

- `id`
- `user_id`
- `question`
- `intent`
- `tokens_used`
- `created_at`

### 7.2 Rule kiểm tra plan

Backend nên có một lớp service kiểu `PlanPolicyService`:

```python
policy.can_use_ai(user_id)
policy.can_add_source(user_id)
policy.can_access_multi_day_summary(user_id)
```

Mỗi API summary/chat/source phải gọi lớp này trước khi thực thi.

---

## 8. RESTful API chuẩn

API phải theo RESTful convention để code sau này sạch và dễ test.

### 8.1 Quy ước chung

- Dùng danh từ số nhiều cho resource: `/api/v1/sources`, `/api/v1/summaries`, `/api/v1/alerts`.
- Dùng HTTP method đúng nghĩa.
- Không dùng verb trong path nếu đã có method phù hợp.
- Response phải có schema ổn định.
- Error phải chuẩn hóa.

### 8.2 Auth endpoints

```http
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

### 8.3 Resource endpoints

```http
GET    /api/v1/sources
POST   /api/v1/sources
GET    /api/v1/sources/{source_id}
PATCH  /api/v1/sources/{source_id}
DELETE /api/v1/sources/{source_id}
POST   /api/v1/sources/{source_id}/activate

GET    /api/v1/history
GET    /api/v1/status
GET    /api/v1/people
GET    /api/v1/people/{track_id}
GET    /api/v1/objects
GET    /api/v1/alerts
GET    /api/v1/alerts/after
GET    /api/v1/fall-events
GET    /api/v1/fall-events/after
GET    /api/v1/reports

POST   /api/v1/streams/start
POST   /api/v1/streams/stop
GET    /api/v1/streams
GET    /api/v1/streams/{source_id}/status
GET    /api/v1/stream/mjpeg
GET    /api/v1/streams/{source_id}/mjpeg
```

### 8.4 AI endpoints

```http
POST /api/v1/chat/query
POST /api/v1/summary/query
POST /api/v1/report/summary
```

### 8.5 REST response mẫu

```json
{
  "data": {
    "id": "source_01",
    "name": "CCTV Quầy lễ tân"
  },
  "meta": {
    "request_id": "req_123",
    "timestamp": "2026-05-14T12:00:00Z"
  }
}
```

### 8.6 REST error mẫu

```json
{
  "error": {
    "code": "PLAN_LIMIT_REACHED",
    "message": "AI query limit reached for current plan",
    "upgrade_required": true
  },
  "meta": {
    "request_id": "req_123",
    "timestamp": "2026-05-14T12:00:00Z"
  }
}
```

---

## 9. API chuẩn cho Flutter

### 9.1 Trạng thái realtime

Flutter chỉ cần đọc:

```json
{
  "data": {
    "action": "walking",
    "confidence": 0.91,
    "timestamp": "2026-05-14T12:00:00Z",
    "fall": false,
    "source_id": "camera_01",
    "plan": "vip"
  },
  "meta": {
    "request_id": "req_123",
    "timestamp": "2026-05-14T12:00:00Z"
  }
}
```

### 9.2 Summary API

```http
POST /api/v1/summary/query
```

Payload:

```json
{
  "scope": "day",
  "from": "2026-05-13T00:00:00Z",
  "to": "2026-05-14T00:00:00Z",
  "source_ids": ["camera_01"],
  "question": "Tóm tắt hôm qua có gì bất thường?"
}
```

### 9.3 Chat API

```http
POST /api/v1/chat/query
```

Giao thức nên trả:

```json
{
  "data": {
    "answer": "...",
    "intent": "activity_summary",
    "insight": {
      "window_ms": 86400000,
      "total_samples": 512,
      "dominant_action": "walking",
      "fall_detected": false
    }
  },
  "meta": {
    "request_id": "req_123",
    "timestamp": "2026-05-14T12:00:00Z"
  }
}
```

---

## 10. Flow xử lý realtime mượt

### 10.1 Luồng chuẩn

1. Camera source đẩy frame vào capture service.
2. Pose service trích keypoints.
3. Action service gom sequence 30 frame.
4. Fall service đánh giá chuyển động và tỉ lệ cơ thể.
5. State service update trạng thái latest.
6. WebSocket push data mỗi 250ms.
7. Summary service định kỳ tổng hợp timeline.
8. AI query chỉ chạy khi user yêu cầu.

### 10.2 Nguyên tắc để mượt

- Không chạy LLM trên từng frame.
- Không block thread inference bằng call mạng.
- Cache summary theo window thời gian.
- Giảm frame skip khi tải cao.
- Tách job nền cho báo cáo và thống kê dài hạn.

---

## 11. UI/UX đề xuất cho Flutter

### 11.1 Giao diện chính

- Màn hình dashboard realtime.
- Tab nguồn video.
- Tab lịch sử và summary.
- Tab hỏi AI.
- Tab cài đặt gói, theme, ngôn ngữ.

### 11.2 Gói thường

- Hiển thị badge `Free`.
- Hiển thị số lượt hỏi còn lại trong ngày.
- Hiển thị nút nâng cấp nếu sắp hết quota.

### 11.3 Gói VIP

- Hiển thị badge `VIP`.
- Cho phép chọn nhiều camera.
- Cho phép lọc summary theo ngày, tuần, custom range.
- Có nút xuất báo cáo.

### 11.4 Ngôn ngữ và theme

- Mặc định tiếng Việt.
- Có toggle ngôn ngữ en/vi.
- Có light/dark mode.
- Text trong app cần được quốc tế hóa, không hardcode.

---

## 12. Logging và audit

Nên log theo 4 lớp:

- Detection log: action, fall, confidence, timestamp.
- Summary log: query, plan, window, response time.
- Source log: add, remove, activate, error.
- Subscription log: upgrade, downgrade, quota hit.

Mỗi log nên có:

- `user_id`
- `source_id`
- `session_id`
- `plan_type`
- `latency_ms`

---

## 13. Kết luận kiến trúc

Kiến trúc này phù hợp với hệ thống hiện tại nếu đi theo nguyên tắc:

- Realtime detection ở backend Python.
- Summary theo data detect, không theo raw video trực tiếp từ client.
- LLM chỉ dùng ở bước cuối để diễn đạt tóm tắt.
- Subscription và quota phải enforce ở backend.
- Flutter chỉ hiển thị, không xử lý AI.

Nếu làm đúng, hệ thống sẽ giữ được độ mượt, dễ mở rộng, và dễ bán theo gói.
