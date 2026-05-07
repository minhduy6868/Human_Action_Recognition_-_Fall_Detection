from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class ActionModel:
    model_path: str
    labels: list[str]
    input_size: int
    hidden_size: int
    num_layers: int
    device: str
    _model: object

    @classmethod
    def load(cls, model_path: str, device: str = "cpu") -> "ActionModel":
        try:
            import torch
        except ImportError as exc:  # pragma: no cover - runtime dependency
            raise RuntimeError("torch is not installed") from exc

        checkpoint = torch.load(model_path, map_location=device)
        labels = checkpoint.get("labels", ["standing", "walking", "sitting", "lying"])
        input_size = int(checkpoint.get("input_size", 99))
        hidden_size = int(checkpoint.get("hidden_size", 128))
        num_layers = int(checkpoint.get("num_layers", 2))

        model = _build_model(input_size, hidden_size, num_layers, len(labels))
        model.load_state_dict(checkpoint["state_dict"])
        model.to(device)
        model.eval()

        return cls(
            model_path=model_path,
            labels=labels,
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            device=device,
            _model=model,
        )

    def predict(self, sequence: list[list[float]]) -> tuple[str, float]:
        try:
            import torch
        except ImportError as exc:  # pragma: no cover - runtime dependency
            raise RuntimeError("torch is not installed") from exc

        if not sequence:
            return "unknown", 0.0

        tensor = torch.tensor(sequence, dtype=torch.float32).unsqueeze(0).to(self.device)
        with torch.no_grad():
            logits = self._model(tensor)
            probs = torch.softmax(logits, dim=-1).cpu().numpy()[0]

        best_idx = int(probs.argmax())
        label = self.labels[best_idx] if best_idx < len(self.labels) else "unknown"
        confidence = float(probs[best_idx])
        return label, confidence


def _build_model(input_size: int, hidden_size: int, num_layers: int, num_classes: int):
    import torch
    import torch.nn as nn

    class LSTMClassifier(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.lstm = nn.LSTM(
                input_size=input_size,
                hidden_size=hidden_size,
                num_layers=num_layers,
                batch_first=True,
            )
            self.fc = nn.Linear(hidden_size, num_classes)

        def forward(self, x):
            out, _ = self.lstm(x)
            last = out[:, -1, :]
            return self.fc(last)

    return LSTMClassifier()
