from typing import Any
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class FallEvent(BaseModel):
    detected: bool = False
    confidence: float = 0.0
    timestamp_ms: int = 0
    action: str = "unknown"
    event_id: int = 0


class AlertEvent(BaseModel):
    alert_id: int = 0
    alert_type: str = "unknown"
    severity: str = "info"
    title: str = ""
    message: str = ""
    timestamp_ms: int = 0
    track_id: str = "0"
    action: str = "unknown"
    confidence: float = 0.0
    source: str = "backend"
    metadata: dict[str, Any] = Field(default_factory=dict)


class PersonClothing(BaseModel):
    """Clothing color information."""
    upper: str = "unknown"  # e.g., "red", "blue", "black"
    lower: str = "unknown"  # e.g., "blue", "white", "black"


class DetectedObject(BaseModel):
    class_id: int
    label: str
    confidence: float
    x1: float
    y1: float
    x2: float
    y2: float
    track_id: str = ""
    clothing: PersonClothing = PersonClothing()  # NEW: Clothing colors for persons
    is_person: bool = False  # True if this is a person


class CameraInfo(BaseModel):
    index: int


class CameraListResponse(BaseModel):
    active_index: int
    items: list[CameraInfo]


class ActionSummaryRequest(BaseModel):
    track_id: str
    window_ms: int


class ActionSummaryResponse(BaseModel):
    track_id: str
    window_ms: int
    labels: list[str]
    confidence: float


class ActionSegment(BaseModel):
    action: str
    start_ms: int
    end_ms: int


class PersonAction(BaseModel):
    """Hành động của 1 người"""
    track_id: str
    action: str
    confidence: float
    fall: bool
    fall_confidence: float
    bbox_x1: float = 0.0
    bbox_y1: float = 0.0
    bbox_x2: float = 0.0
    bbox_y2: float = 0.0
    clothing: PersonClothing = PersonClothing()  # Màu áo quần
    person_id: str = ""  # ID nhận diện người (dựa trên visual features)


class RealtimeStatus(BaseModel):
    action: str = "idle"  # ← Hành động của người chính (tương thích cũ)
    confidence: float = 0.0
    fall: bool = False
    fall_confidence: float = 0.0
    timestamp_ms: int = 0
    track_id: str = "0"  # ← Track ID người chính
    objects: list[DetectedObject] = Field(default_factory=list)  # ← TẤT CẢ đối tượng (người + vật khác)
    people: list[PersonAction] = Field(default_factory=list)  # ← NEW: Danh sách tất cả người với hành động


class HistoryResponse(BaseModel):
    items: list[RealtimeStatus]


class ActionTimelineResponse(BaseModel):
    window_ms: int
    segments: list[ActionSegment]


class ActivityInsightResponse(BaseModel):
    window_ms: int
    total_samples: int
    dominant_action: str
    dominant_action_ratio: float
    action_durations_ms: dict[str, int]
    segments: list[ActionSegment]
    fall_detected: bool
    fall_events: list[FallEvent]
    max_people_count: int = 0
    avg_people_count: float = 0.0
    max_objects_count: int = 0
    avg_objects_count: float = 0.0
    multi_person_frames: int = 0
    top_object_labels: dict[str, int] = Field(default_factory=dict)


class ReportRequest(BaseModel):
    window_ms: int = 60 * 60 * 1000
    persist: bool = True


class SummaryReportResponse(BaseModel):
    report_id: int = 0
    title: str = "Activity Summary"
    window_ms: int
    generated_at_ms: int
    insight: ActivityInsightResponse
    alert_counts: dict[str, int] = Field(default_factory=dict)


class SummaryQueryRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    from_dt: datetime | None = Field(default=None, alias="from")
    to_dt: datetime | None = Field(default=None, alias="to")
    source_ids: list[str] = Field(default_factory=list)
    question: str | None = None


class SummaryQueryResponse(BaseModel):
    from_ms: int
    to_ms: int
    source_ids: list[str]
    insight: ActivityInsightResponse
    answer: str | None = None
    intent: str | None = None


class ChatQueryRequest(BaseModel):
    question: str
    window_ms: int | None = None


class ChatQueryResponse(BaseModel):
    answer: str
    intent: str
    insight: ActivityInsightResponse


class AuthLoginRequest(BaseModel):
    email: str
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str


class AuthRefreshRequest(BaseModel):
    refresh_token: str


class AuthTokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_expires_in: int


class RegisterRequest(BaseModel):
    email: str
    name: str | None = ""
    password: str


class PasswordResetRequest(BaseModel):
    email: str
    otp: str
    new_password: str


class UserProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    name: str
    role: str
    plan: str
    created_at: datetime | None = None


class SourceCreate(BaseModel):
    name: str
    source_type: str
    source_url: str
    is_active: bool = False


class SourceUpdate(BaseModel):
    name: str | None = None
    source_type: str | None = None
    source_url: str | None = None
    is_active: bool | None = None


class SourceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    source_type: str
    source_url: str
    is_active: bool


class DetectionLogResponse(BaseModel):
    id: int
    timestamp_ms: int
    track_id: str
    action: str
    confidence: float
    fall: bool
    fall_confidence: float
    people_count: int
    objects_count: int
    source_id: str | None


class DetectionLogDetailResponse(DetectionLogResponse):
    people: list[dict[str, Any]]
    objects: list[dict[str, Any]]


class ChatHistoryResponse(BaseModel):
    id: int
    question: str
    answer: str
    intent: str
    window_ms: int
    source_id: str | None
    created_at: datetime


class DeviceTokenRequest(BaseModel):
    token: str
    platform: str = "unknown"
    source_id: str | None = None


class DeviceTokenResponse(BaseModel):
    registered: bool = True


class DeviceTokenRemoveRequest(BaseModel):
    token: str


class OtpRequestPayload(BaseModel):
    email: str
    purpose: str = "verify"


class OtpVerifyPayload(BaseModel):
    email: str
    otp: str
    purpose: str = "verify"


class OtpResponse(BaseModel):
    ok: bool
    expires_in: int | None = None


class StreamStartRequest(BaseModel):
    source_id: str
    source_type: str
    source_url: str


class StreamStopRequest(BaseModel):
    source_id: str


class StreamActivateRequest(BaseModel):
    source_id: str


class StreamSessionResponse(BaseModel):
    source_id: str
    user_id: str | None
    source_type: str
    source_url: str
    active: bool = True
