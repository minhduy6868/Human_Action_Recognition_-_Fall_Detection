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
        except ImportError:
            logger.warning("torch not available: action model disabled (will use fallback)")
            return cls(
                model_path=model_path,
                labels=["standing", "walking", "sitting", "lying"],
                input_size=0,
                hidden_size=0,
                num_layers=0,
                device=device,
                _model=None,
            )

        try:
            checkpoint = torch.load(model_path, map_location=device)
        except Exception as exc:
            logger.exception("Failed to load action model checkpoint '%s': %s", model_path, exc)
            return cls(
                model_path=model_path,
                labels=["standing", "walking", "sitting", "lying"],
                input_size=0,
                hidden_size=0,
                num_layers=0,
                device=device,
                _model=None,
            )

        labels = checkpoint.get("labels", ["standing", "walking", "sitting", "lying"])
        input_size = int(checkpoint.get("input_size", 99))
        hidden_size = int(checkpoint.get("hidden_size", 128))
        num_layers = int(checkpoint.get("num_layers", 2))

        try:
            model = _build_model(input_size, hidden_size, num_layers, len(labels))
            model.load_state_dict(checkpoint["state_dict"])
            model.to(device)
            model.eval()
        except Exception as exc:
            logger.exception("Failed to build/load action model network: %s", exc)
            return cls(
                model_path=model_path,
                labels=labels,
                input_size=input_size,
                hidden_size=hidden_size,
                num_layers=num_layers,
                device=device,
                _model=None,
            )

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
        if not sequence:
            return "unknown", 0.0

        if self._model is None:
            logger.debug("ActionModel._model is None; returning unknown")
            return "unknown", 0.0

        # validate input size (if known)
        if self.input_size and len(sequence[0]) != self.input_size:
            logger.warning(
                "Sequence feature size (%d) != model input_size (%d); returning unknown",
                len(sequence[0]),
                self.input_size,
            )
            return "unknown", 0.0

        try:
            import torch
        except ImportError:
            logger.debug("torch not available at predict time; returning unknown")
            return "unknown", 0.0

        try:
            tensor = torch.tensor(sequence, dtype=torch.float32).unsqueeze(0).to(self.device)
            with torch.no_grad():
                logits = self._model(tensor)
                probs = torch.softmax(logits, dim=-1).cpu().numpy()[0]
        except Exception:
            logger.exception("Error during ActionModel.predict")
            return "unknown", 0.0

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
