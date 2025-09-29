from datetime import datetime
from typing import Any, Dict

from fastapi import FastAPI, Request

app = FastAPI(title="Mock Deploy Worker", version="0.1.0")


def _log_step(step: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    timestamp = datetime.utcnow().isoformat() + "Z"
    message = {"timestamp": timestamp, "step": step, "payload": payload}
    print(f"[WORKER] {message}")
    return {"ok": True, "step": step, "receivedAt": timestamp, **({"payload": payload})}


@app.post("/provision")
async def provision(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("provision", payload)
    return response


@app.post("/traffic")
async def traffic(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("traffic", payload)
    return response


@app.post("/verify")
async def verify(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step(
        "verify",
        {
            **payload,
            "metrics": {"latencyMs": 123, "errorRate": 0.01},
        },
    )
    return response


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat() + "Z"}
