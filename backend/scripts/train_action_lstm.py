import argparse
from pathlib import Path

import numpy as np


def main() -> None:
    parser = argparse.ArgumentParser(description="Train LSTM action model")
    parser.add_argument("--data", required=True, help="Input NPZ from build_sequences")
    parser.add_argument("--output", required=True, help="Output model path")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--hidden", type=int, default=128)
    parser.add_argument("--layers", type=int, default=2)
    args = parser.parse_args()

    import torch
    import torch.nn as nn
    from torch.utils.data import DataLoader, TensorDataset

    data = np.load(args.data, allow_pickle=True)
    x = data["x"]
    y = data["y"]
    labels = data["labels"].tolist()

    x_tensor = torch.tensor(x, dtype=torch.float32)
    y_tensor = torch.tensor(y, dtype=torch.long)

    dataset = TensorDataset(x_tensor, y_tensor)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=True)

    input_size = x_tensor.shape[-1]
    num_classes = len(labels)

    class LSTMClassifier(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.lstm = nn.LSTM(
                input_size=input_size,
                hidden_size=args.hidden,
                num_layers=args.layers,
                batch_first=True,
            )
            self.fc = nn.Linear(args.hidden, num_classes)

        def forward(self, data):
            out, _ = self.lstm(data)
            last = out[:, -1, :]
            return self.fc(last)

    model = LSTMClassifier()
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    criterion = nn.CrossEntropyLoss()

    model.train()
    for epoch in range(args.epochs):
        total_loss = 0.0
        for batch_x, batch_y in loader:
            optimizer.zero_grad()
            logits = model(batch_x)
            loss = criterion(logits, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += float(loss.item())
        avg_loss = total_loss / max(len(loader), 1)
        print(f"epoch={epoch + 1} loss={avg_loss:.4f}")

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "state_dict": model.state_dict(),
            "labels": labels,
            "input_size": input_size,
            "hidden_size": args.hidden,
            "num_layers": args.layers,
        },
        output_path,
    )


if __name__ == "__main__":
    main()
