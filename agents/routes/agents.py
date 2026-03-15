"""FastAPI routes for the agent endpoints."""
from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException

from agents import CoachAgent, DashboardAgent, PlannerAgent
from models import (
    AgentResponse,
    CoachAgentRequest,
    DashboardAgentRequest,
    InsightAgentRequest,
)

log = logging.getLogger(__name__)
router = APIRouter(prefix="/agents", tags=["agents"])


@router.post("/planner", response_model=AgentResponse)
async def planner(req: InsightAgentRequest) -> AgentResponse:
    """
    Extract todos, routines, reminders, and notes from the conversation.

    Returns structured `insights` list alongside a natural-language reply.
    """
    try:
        agent = PlannerAgent()
        reply, structured = await agent.run(
            req.messages,
            existing_insights=req.existing_insights,
        )
        return AgentResponse(agent="planner", reply=reply, structured=structured)
    except Exception as exc:
        log.exception("planner agent error")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/dashboard", response_model=AgentResponse)
async def dashboard(req: DashboardAgentRequest) -> AgentResponse:
    """
    Generate up to 5 dashboard cards from the user's insights and conversation.

    Returns structured `cards` list alongside a natural-language reply.
    """
    try:
        agent = DashboardAgent()
        reply, structured = await agent.run(
            req.messages,
            insights=req.insights,
        )
        return AgentResponse(agent="dashboard", reply=reply, structured=structured)
    except Exception as exc:
        log.exception("dashboard agent error")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/coach", response_model=AgentResponse)
async def coach(req: CoachAgentRequest) -> AgentResponse:
    """
    Conversational health & wellness coach.  Optionally driven by a Persona's
    system prompt so the app can swap personalities.
    """
    try:
        agent = CoachAgent(persona_prompt=req.persona_prompt)
        reply, structured = await agent.run(req.messages)
        return AgentResponse(agent="coach", reply=reply, structured=structured)
    except Exception as exc:
        log.exception("coach agent error")
        raise HTTPException(status_code=500, detail=str(exc)) from exc
