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


@app.post("/create_infrastructure")
async def create_infrastructure(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("create_infrastructure", payload)
    return response


@app.post("/wait_infrastructure_created")
async def wait_infrastructure_created(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("wait_infrastructure_created", payload)
    return response


@app.post("/swap_traffic")
async def swap_traffic(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("swap_traffic", payload)
    return response


@app.post("/effective_status")
async def effective_status(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    # Simular éxito o fallo basado en el scope
    scope = payload.get("scope", "")
    success = scope and scope.startswith("svc-")
    print(f"[DEBUG] Scope: {scope}, Success: {success}")
    response = _log_step("effective_status", {
        **payload,
        "success": success,
        "status": "healthy" if success else "unhealthy",
        "metrics": {"latencyMs": 45, "errorRate": 0.001 if success else 0.15}
    })
    return response


@app.post("/finalize_deployment")
async def finalize_deployment(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("finalize_deployment", payload)
    return response


@app.post("/rollback_deployment")
async def rollback_deployment(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("rollback_deployment", payload)
    return response


@app.post("/cleanup_old_resources")
async def cleanup_old_resources(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("cleanup_old_resources", payload)
    return response


@app.post("/update_monitoring")
async def update_monitoring(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("update_monitoring", payload)
    return response


@app.post("/notify_success")
async def notify_success(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("notify_success", payload)
    return response


@app.post("/restore_previous_traffic")
async def restore_previous_traffic(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("restore_previous_traffic", payload)
    return response


@app.post("/cleanup_failed_resources")
async def cleanup_failed_resources(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("cleanup_failed_resources", payload)
    return response


@app.post("/notify_failure")
async def notify_failure(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    response = _log_step("notify_failure", payload)
    return response


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat() + "Z"}
