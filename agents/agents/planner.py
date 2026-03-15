"""
Planner agent — listens to conversation and extracts structured insights:
todos, routines, reminders, and notes.
"""
from __future__ import annotations

from typing import Any

import google.generativeai as genai

from agents.base import BaseAgent
from models import ChatMessage, Insight, InsightType


_SYSTEM = """
You are a proactive planning assistant embedded in a health and wellness app.

Your job: analyse the user's conversation and extract actionable items.

When you identify one or more items, call the `save_insights` tool with a
JSON array.  Each item must have:
  - type: "todo" | "routine" | "reminder" | "note"
  - content: short, actionable sentence (≤120 chars)

After saving, give the user a brief natural-language confirmation.
If there is nothing to extract, just reply normally.
""".strip()


_SAVE_INSIGHTS_DECL = genai.protos.FunctionDeclaration(
    name="save_insights",
    description="Persist extracted insight items for the user.",
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "items": genai.protos.Schema(
                type=genai.protos.Type.ARRAY,
                items=genai.protos.Schema(
                    type=genai.protos.Type.OBJECT,
                    properties={
                        "type": genai.protos.Schema(
                            type=genai.protos.Type.STRING,
                            enum=["todo", "routine", "reminder", "note"],
                        ),
                        "content": genai.protos.Schema(type=genai.protos.Type.STRING),
                    },
                    required=["type", "content"],
                ),
            )
        },
        required=["items"],
    ),
)


class PlannerAgent(BaseAgent):
    name = "planner"
    system_prompt = _SYSTEM
    tools = [genai.protos.Tool(function_declarations=[_SAVE_INSIGHTS_DECL])]

    def __init__(self) -> None:
        super().__init__()
        self._saved: list[Insight] = []

    async def run(
        self,
        messages: list[ChatMessage],
        extra_system: str = "",
        existing_insights: list[Insight] | None = None,
    ) -> tuple[str, dict[str, Any] | None]:
        self._saved = []

        if existing_insights:
            ctx = "Existing insights (do not duplicate):\n" + "\n".join(
                f"- [{i.type}] {i.content}" for i in existing_insights
            )
            extra_system = f"{ctx}\n\n{extra_system}".strip()

        text, _ = await super().run(messages, extra_system)

        structured = (
            {"insights": [i.model_dump() for i in self._saved]}
            if self._saved
            else None
        )
        return text, structured

    async def handle_tool_call(self, name: str, args: dict[str, Any]) -> Any:
        if name == "save_insights":
            items = args.get("items", [])
            for item in items:
                try:
                    self._saved.append(
                        Insight(
                            type=InsightType(item["type"]),
                            content=item["content"],
                        )
                    )
                except Exception:
                    pass
            return {"saved": len(self._saved)}
        return await super().handle_tool_call(name, args)
