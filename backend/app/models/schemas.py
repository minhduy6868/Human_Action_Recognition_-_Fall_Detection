from typing import Any

from pydantic import BaseModel, Field


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


class DetectedObject(BaseModel):
    class_id: int
    label: str
    confidence: float
    x1: float
    y1: float
    x2: float
    y2: float
    track_id: str = ""


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


class RealtimeStatus(BaseModel):
    action: str = "idle"
    confidence: float = 0.0
    fall: bool = False
    fall_confidence: float = 0.0
    timestamp_ms: int = 0
    track_id: str = "0"
    objects: list[DetectedObject] = Field(default_factory=list)


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


class ChatQueryRequest(BaseModel):
    question: str
    window_ms: int | None = None


class ChatQueryResponse(BaseModel):
    answer: str
    intent: str
    insight: ActivityInsightResponse
