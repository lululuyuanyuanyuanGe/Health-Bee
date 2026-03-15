"""
Coach agent — gives motivational, personalised health & wellness advice.
Uses the active Persona's system prompt as its personality.
"""
from __future__ import annotations

from typing import Any

from agents.base import BaseAgent, _extract_json
from models import ChatMessage

import google.generativeai as genai


_DEFAULT_PERSONA = """
You are a warm, knowledgeable health and wellness coach. You listen carefully,
ask clarifying questions when needed, and give practical, evidence-based advice.
Keep responses concise and encouraging.
""".strip()


class CoachAgent(BaseAgent):
    name = "coach"
    tools = []  # coach is conversational, no tool calls

    def __init__(self, persona_prompt: str = "") -> None:
        self.system_prompt = persona_prompt.strip() or _DEFAULT_PERSONA
        super().__init__()

    async def run(
        self,
        messages: list[ChatMessage],
        extra_system: str = "",
    ) -> tuple[str, dict[str, Any] | None]:
        return await super().run(messages, extra_system)

    async def handle_tool_call(self, name: str, args: dict[str, Any]) -> Any:
        # Coach has no tools; this should never be called.
        return {}
