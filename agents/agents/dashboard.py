"""
Dashboard agent — synthesises the user's insights into dashboard cards
(reminder, social, insight, discover, tip).
"""
from __future__ import annotations

from typing import Any

import google.generativeai as genai

from agents.base import BaseAgent
from models import ChatMessage, DashboardCard, DashboardCardType, Insight


_SYSTEM = """
You are the dashboard curator for a health and wellness app.

Given the user's current insights (todos, routines, reminders, notes) and any
conversation context, generate a small set of dashboard cards.

Call `publish_cards` with an array of cards.  Each card:
  - type: "reminder" | "social" | "insight" | "discover" | "tip"
  - content: one concise sentence (≤160 chars)

Rules:
  - Max 5 cards total.
  - At least one card must be type "tip" with an evidence-based health tip.
  - Prioritise overdue reminders and incomplete todos.
  - Be warm, motivating, and specific.
""".strip()


_PUBLISH_CARDS_DECL = genai.protos.FunctionDeclaration(
    name="publish_cards",
    description="Publish dashboard cards to the user's home screen.",
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "cards": genai.protos.Schema(
                type=genai.protos.Type.ARRAY,
                items=genai.protos.Schema(
                    type=genai.protos.Type.OBJECT,
                    properties={
                        "type": genai.protos.Schema(
                            type=genai.protos.Type.STRING,
                            enum=["reminder", "social", "insight", "discover", "tip"],
                        ),
                        "content": genai.protos.Schema(type=genai.protos.Type.STRING),
                    },
                    required=["type", "content"],
                ),
            )
        },
        required=["cards"],
    ),
)


class DashboardAgent(BaseAgent):
    name = "dashboard"
    system_prompt = _SYSTEM
    tools = [genai.protos.Tool(function_declarations=[_PUBLISH_CARDS_DECL])]

    def __init__(self) -> None:
        super().__init__()
        self._cards: list[DashboardCard] = []

    async def run(
        self,
        messages: list[ChatMessage],
        extra_system: str = "",
        insights: list[Insight] | None = None,
    ) -> tuple[str, dict[str, Any] | None]:
        self._cards = []

        if insights:
            ctx = "User's current insights:\n" + "\n".join(
                f"- [{i.type}] {'✓' if i.is_completed else '○'} {i.content}"
                for i in insights
            )
            extra_system = f"{ctx}\n\n{extra_system}".strip()

        text, _ = await super().run(messages, extra_system)

        structured = (
            {"cards": [c.model_dump() for c in self._cards]} if self._cards else None
        )
        return text, structured

    async def handle_tool_call(self, name: str, args: dict[str, Any]) -> Any:
        if name == "publish_cards":
            for item in args.get("cards", []):
                try:
                    self._cards.append(
                        DashboardCard(
                            type=DashboardCardType(item["type"]),
                            content=item["content"],
                        )
                    )
                except Exception:
                    pass
            return {"published": len(self._cards)}
        return await super().handle_tool_call(name, args)
