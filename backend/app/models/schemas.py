from pydantic import BaseModel


class FallEvent(BaseModel):
    detected: bool = False
    confidence: float = 0.0
    timestamp_ms: int = 0


class ActionSummaryRequest(BaseModel):
    track_id: str
    window_ms: int


class ActionSummaryResponse(BaseModel):
    track_id: str
    window_ms: int
    labels: list[str]
    confidence: float


class RealtimeStatus(BaseModel):
    action: str = "idle"
    confidence: float = 0.0
    fall: bool = False
    timestamp_ms: int = 0
    track_id: str = "0"


class HistoryResponse(BaseModel):
    items: list[RealtimeStatus]
