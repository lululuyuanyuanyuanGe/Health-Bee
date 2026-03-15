"""Base agent: wraps Gemini and provides a simple agentic loop with tools."""
from __future__ import annotations

import json
import logging
from typing import Any

import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration, Tool

from config import settings
from models import ChatMessage, MessageRole

log = logging.getLogger(__name__)

genai.configure(api_key=settings.gemini_api_key)


class BaseAgent:
    """
    A thin agentic loop on top of Gemini.

    Subclasses declare:
      - name          : str
      - system_prompt : str
      - tools         : list[Tool]   (Gemini function declarations)

    and implement:
      - handle_tool_call(name, args) -> Any
    """

    name: str = "base"
    system_prompt: str = "You are a helpful assistant."
    tools: list[Tool] = []

    def __init__(self) -> None:
        self._model = genai.GenerativeModel(
            model_name=settings.gemini_model,
            system_instruction=self.system_prompt,
            tools=self.tools or None,
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def run(
        self,
        messages: list[ChatMessage],
        extra_system: str = "",
    ) -> tuple[str, dict[str, Any] | None]:
        """
        Drive the agent loop.

        Returns (text_reply, structured_output).
        structured_output is populated if the agent produces JSON in the
        final assistant message (wrapped in ```json ... ```).
        """
        history = self._build_history(messages[:-1])
        last = messages[-1].content

        if extra_system:
            last = f"[Context]\n{extra_system}\n\n[User]\n{last}"

        chat = self._model.start_chat(history=history)

        # Agentic loop: keep going until no more tool calls.
        response = await chat.send_message_async(last)

        for _ in range(5):  # max 5 tool-call rounds
            if not response.candidates:
                break
            part = response.candidates[0].content.parts[0]
            if not hasattr(part, "function_call") or part.function_call.name == "":
                break

            fc = part.function_call
            log.info("agent %s calling tool %s", self.name, fc.name)
            tool_result = await self.handle_tool_call(fc.name, dict(fc.args))

            response = await chat.send_message_async(
                genai.protos.Content(
                    parts=[genai.protos.Part(
                        function_response=genai.protos.FunctionResponse(
                            name=fc.name,
                            response={"result": tool_result},
                        )
                    )],
                    role="function",
                )
            )

        text = response.text.strip()
        structured = _extract_json(text)
        return text, structured

    # ------------------------------------------------------------------
    # Overridable
    # ------------------------------------------------------------------

    async def handle_tool_call(self, name: str, args: dict[str, Any]) -> Any:
        """Override in subclasses to handle tool calls."""
        raise NotImplementedError(f"Agent {self.name} has no handler for tool {name!r}")

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _build_history(messages: list[ChatMessage]) -> list[dict]:
        result = []
        for m in messages:
            role = "model" if m.role == MessageRole.assistant else "user"
            result.append({"role": role, "parts": [m.content]})
        return result


def _extract_json(text: str) -> dict[str, Any] | None:
    """Pull the first ```json ... ``` block from text, if present."""
    import re
    match = re.search(r"```json\s*([\s\S]*?)```", text)
    if not match:
        return None
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError:
        return None
