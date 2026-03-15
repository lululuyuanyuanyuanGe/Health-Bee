"""Health-Bee agent server entry point."""
import logging

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routes.agents import router as agents_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)

app = FastAPI(
    title="Health-Bee Agent Server",
    description="Specialised AI agents: planner, dashboard, coach.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(agents_router)


@app.get("/health", tags=["meta"])
def health() -> dict:
    return {"status": "ok", "agents": ["planner", "dashboard", "coach"]}


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.agent_server_port,
        reload=True,
    )
