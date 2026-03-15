"""Shared request/response models mirroring AppModels.swift."""
from __future__ import annotations

from enum import Enum
from typing import Any
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Chat primitives (shared with the Node backend)
# ---------------------------------------------------------------------------

class MessageRole(str, Enum):
    user = "user"
    assistant = "assistant"


class ChatMessage(BaseModel):
    role: MessageRole
    content: str


# ---------------------------------------------------------------------------
# App domain models
# ---------------------------------------------------------------------------

class InsightType(str, Enum):
    todo = "todo"
    routine = "routine"
    note = "note"
    reminder = "reminder"


class Insight(BaseModel):
    type: InsightType
    content: str
    is_completed: bool = False


class DashboardCardType(str, Enum):
    reminder = "reminder"
    social = "social"
    insight = "insight"
    discover = "discover"
    tip = "tip"


class DashboardCard(BaseModel):
    type: DashboardCardType
    content: str


# ---------------------------------------------------------------------------
# Agent request / response envelopes
# ---------------------------------------------------------------------------

class AgentRequest(BaseModel):
    """Generic request envelope sent to any agent endpoint."""
    messages: list[ChatMessage] = Field(..., min_length=1)
    context: dict[str, Any] = Field(default_factory=dict,
        description="Agent-specific context (insights, persona, etc.)")


class AgentResponse(BaseModel):
    """Generic response envelope returned by every agent."""
    agent: str
    reply: str
    structured: dict[str, Any] | None = None


# ---------------------------------------------------------------------------
# Specialised request types
# ---------------------------------------------------------------------------

class InsightAgentRequest(AgentRequest):
    """Planner agent: extract actionable insights from conversation."""
    existing_insights: list[Insight] = Field(default_factory=list)


class DashboardAgentRequest(AgentRequest):
    """Dashboard agent: generate cards summarising the user's day."""
    insights: list[Insight] = Field(default_factory=list)


class CoachAgentRequest(AgentRequest):
    """Coach agent: give motivational / health advice."""
    persona_prompt: str = ""
