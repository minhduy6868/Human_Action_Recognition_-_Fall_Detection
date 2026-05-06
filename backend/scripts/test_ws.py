import argparse
import asyncio

import websockets


def build_uri(channel: str, host: str, port: int) -> str:
    if channel == "fall":
        return f"ws://{host}:{port}/api/ws/fall-alerts"
    return f"ws://{host}:{port}/api/ws"


async def main() -> None:
    parser = argparse.ArgumentParser(description="Simple websocket demo client")
    parser.add_argument("--channel", choices=["status", "fall"], default="status")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--count", type=int, default=5)
    args = parser.parse_args()

    uri = build_uri(args.channel, args.host, args.port)
    print(f"Connecting: {uri}")
    try:
        async with websockets.connect(uri) as ws:
            for _ in range(args.count):
                msg = await ws.recv()
                print(msg)
    except Exception as exc:
        print("ERROR", exc)


if __name__ == "__main__":
    asyncio.run(main())
