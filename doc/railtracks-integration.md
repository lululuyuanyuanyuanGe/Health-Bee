# CueBee × Railtracks — Agentic System Integration Design

> **Version:** 1.0
> **Date:** March 2026
> Railtracks replaces LangGraph as the orchestration layer for all 10 agents. LiteLLM (bundled with Railtracks) replaces the custom `providers.json` LLM factory. Built-in Railtracks observability replaces manual `agent_log` / `llm_log` instrumentation.

---

## Table of Contents

1. [Why Railtracks](#1-why-railtracks)
2. [Integration Architecture](#2-integration-architecture)
3. [Layer Migration Map](#3-layer-migration-map)
4. [Tool Layer — `@rt.function_node`](#4-tool-layer--rtfunction_node)
5. [Agent Nodes — `rt.agent_node`](#5-agent-nodes--rtagent_node)
6. [Flow Definitions — `rt.Flow`](#6-flow-definitions--rtflow)
   - [Wingman Flow](#61-wingman-flow)
   - [Background Flow](#62-background-flow)
   - [Dashboard Flow](#63-dashboard-flow)
   - [Copilot Flow](#64-copilot-flow)
7. [LLM Provider via LiteLLM](#7-llm-provider-via-litellm)
8. [MCP Tools Integration](#8-mcp-tools-integration)
9. [Observability](#9-observability)
10. [gRPC Streaming Adapter](#10-grpc-streaming-adapter)
11. [Migration Plan](#11-migration-plan)
12. [File Structure After Migration](#12-file-structure-after-migration)
13. [Configuration](#13-configuration)

---

## 1. Why Railtracks

### Current pain points with LangGraph

| Pain point | Detail |
|---|---|
| `stream_mode="messages"` bug | Buffers entire response when tools bound (LangGraph #5249) — must use `astream_events` workaround |
| `create_react_agent` deprecated | Replacement `create_agent` has open bugs (#34613, #34234, #34463) with Gemini + streaming |
| Suppressed deprecation warnings | Manually suppressed per-call with `warnings.catch_warnings()` |
| No built-in observability | Custom `agent_log` / `llm_log` / `debug_logger.py` maintained manually |
| Graph-centric DSL | ReAct behaviour requires understanding LangGraph internals to debug or extend |
| Per-agent glue code | Each of the 10 agents has bespoke prompt construction, streaming loops, and error handling |

### What Railtracks provides

| Capability | Railtracks approach |
|---|---|
| **Flows are just Python** | No DSL, no YAML, no graph configuration — branching and looping are plain `if` / `while` |
| **`@rt.function_node`** | Decorator turns any function into an LLM-callable tool (replaces `@langchain.tool`) |
| **`rt.agent_node`**  | Wraps an LLM + tool set into a reusable, observable agent node |
| **`rt.Flow`** | Composes agent nodes into pipelines; handles streaming, error recovery, retries |
| **LiteLLM built-in** | Single gateway to all providers (Gemini, Claude, DeepSeek, Kimi, GLM …) |
| **Built-in observability** | Step-by-step execution traces, local visualiser, no signup required |
| **MCP client built-in** | Native MCP protocol support — no custom `mcp_manager.py` needed |

---

## 2. Integration Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     PYTHON SERVICE  :5001  (after Railtracks)                ║
║                                                                               ║
║  ┌─────────────────────────────────────────────────────────────────────────┐ ║
║  │  RAILTRACKS LAYER                                                        │ ║
║  │                                                                          │ ║
║  │  ┌─────────────────────────────────────────────────────────────────┐    │ ║
║  │  │  rt.Flow: wingman_flow                                          │    │ ║
║  │  │                                                                 │    │ ║
║  │  │  passive_node ──► [1] passive_agent                            │    │ ║
║  │  │                                                                 │    │ ║
║  │  │  proactive_node ─► [2] gate_agent                              │    │ ║
║  │  │                      │ trigger=True                             │    │ ║
║  │  │                      └──► [3] assist_agent (tools + ReAct)     │    │ ║
║  │  │                                                                 │    │ ║
║  │  │  threshold_node ─► [4] compactor_agent                         │    │ ║
║  │  │  disconnect_node ─► [5] end_summary_agent                       │    │ ║
║  │  └─────────────────────────────────────────────────────────────────┘    │ ║
║  │                                                                          │ ║
║  │  ┌─────────────────────────────────────────────────────────────────┐    │ ║
║  │  │  rt.Flow: copilot_flow                                          │    │ ║
║  │  │  [6] copilot_agent  (built-in tools + MCP tools)                │    │ ║
║  │  │  [7] insights_agent  (async, on threshold)                       │    │ ║
║  │  └─────────────────────────────────────────────────────────────────┘    │ ║
║  │                                                                          │ ║
║  │  ┌─────────────────────────────────────────────────────────────────┐    │ ║
║  │  │  rt.Flow: background_flow                                        │    │ ║
║  │  │  [8] file_summarizer_agent                                       │    │ ║
║  │  │  [9] persona_generator_agent                                     │    │ ║
║  │  └─────────────────────────────────────────────────────────────────┘    │ ║
║  │                                                                          │ ║
║  │  ┌─────────────────────────────────────────────────────────────────┐    │ ║
║  │  │  rt.Flow: dashboard_flow                                         │    │ ║
║  │  │  [10] dashboard_agent  (web_search tool + ReAct)                 │    │ ║
║  │  └─────────────────────────────────────────────────────────────────┘    │ ║
║  │                                                                          │ ║
║  │  ┌───────────────────────────────────────────────────────────────────┐  │ ║
║  │  │  SHARED TOOL REGISTRY  (@rt.function_node)                        │  │ ║
║  │  │  get_weather · get_datetime · web_search · search_news            │  │ ║
║  │  │  get_stock · wikipedia · summarize_url · set_reminder             │  │ ║
║  │  │  daily_briefing · [MCP tools via rt.mcp_client]                  │  │ ║
║  │  └───────────────────────────────────────────────────────────────────┘  │ ║
║  │                                                                          │ ║
║  │  ┌───────────────────────────────────────────────────────────────────┐  │ ║
║  │  │  LiteLLM  (Railtracks built-in)                                   │  │ ║
║  │  │  replaces: llm_provider.py + providers.json                        │  │ ║
║  │  │  gemini/ · anthropic/ · deepseek/ · moonshot/ · openai/           │  │ ║
║  │  └───────────────────────────────────────────────────────────────────┘  │ ║
║  │                                                                          │ ║
║  │  ┌───────────────────────────────────────────────────────────────────┐  │ ║
║  │  │  Railtracks built-in observability                                │  │ ║
║  │  │  replaces: debug_logger.py + agent_log + llm_log                  │  │ ║
║  │  │  step traces · token counts · latency · local visualiser          │  │ ║
║  │  └───────────────────────────────────────────────────────────────────┘  │ ║
║  └─────────────────────────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 3. Layer Migration Map

```
BEFORE (LangGraph + custom)              AFTER (Railtracks)
══════════════════════════════════       ══════════════════════════════════════
@langchain.tool                    ───►  @rt.function_node
LangChain StructuredTool (MCP)     ───►  rt.mcp_client  (native MCP)
get_llm("role")                    ───►  rt.llm.LiteLLM("gemini/...")
create_react_agent(llm, tools)     ───►  rt.agent_node("name", tool_nodes, llm)
agent.astream_events(v="v2")       ───►  flow.stream()
stream_agent_response() adapter    ───►  flow.stream()  (native streaming)
agent.ainvoke(...)                 ───►  flow.invoke()
custom providers.json factory      ───►  LiteLLM model strings
debug_logger.py / agent_log        ───►  rt.trace()  (built-in)
mcp_manager.py (750 lines)         ───►  rt.mcp_client  (10 lines)
astream_events workaround          ───►  eliminated (Railtracks streams natively)
warnings.filterwarnings suppress   ───►  eliminated
```

---

## 4. Tool Layer — `@rt.function_node`

All tools in `tools.py` are migrated from `@langchain.tool` to `@rt.function_node`. The decorator signature is identical — only the import changes.

```python
# service/rt_tools.py

import railtracks as rt
import httpx, yfinance as yf, wikipedia
from ddgs import DDGS
from zoneinfo import ZoneInfo
from datetime import datetime
from database import get_db_connection
from llm_provider import get_llm          # still used inside summarize_url

# ── Weather ──────────────────────────────────────────────────────────────────

@rt.function_node
async def get_weather(location: str) -> str:
    """Get the current weather for a location."""
    # ... identical implementation to tools.py ...

# ── Date / Time ───────────────────────────────────────────────────────────────

@rt.function_node
async def get_current_datetime(timezone: str = "UTC") -> str:
    """Get the current date and time in the given timezone."""
    tz = ZoneInfo(timezone)
    now = datetime.now(tz)
    return now.strftime("%A, %B %d, %Y at %I:%M %p %Z")

# ── Web Search ────────────────────────────────────────────────────────────────

@rt.function_node
async def web_search(query: str) -> str:
    """Search the web using DuckDuckGo. Use for current events and facts."""
    results = list(DDGS().text(query, max_results=3))
    if not results:
        return "No results found."
    return "\n\n".join(
        f"{r['title']}\n{r['href']}\n{r['body']}" for r in results
    )

# ── News ──────────────────────────────────────────────────────────────────────

@rt.function_node
async def search_news(query: str) -> str:
    """Search for recent news articles."""
    results = list(DDGS().news(query, max_results=5))
    return "\n\n".join(
        f"[{r['date']}] {r['title']} — {r['source']}\n{r['url']}"
        for r in results
    ) if results else "No news found."

# ── Stocks ────────────────────────────────────────────────────────────────────

@rt.function_node
async def get_stock_price(symbol: str) -> str:
    """Get the current stock price for a ticker symbol (e.g. AAPL, TSLA)."""
    ticker = yf.Ticker(symbol.upper())
    info = ticker.info
    price = info.get("currentPrice") or info.get("regularMarketPrice", "N/A")
    return f"{symbol.upper()}: ${price}"

# ── Wikipedia ─────────────────────────────────────────────────────────────────

@rt.function_node
async def wikipedia_search(query: str) -> str:
    """Search Wikipedia for background information on a topic."""
    try:
        return wikipedia.summary(query, sentences=5, auto_suggest=False)
    except wikipedia.DisambiguationError as e:
        return wikipedia.summary(e.options[0], sentences=5)

# ── URL Summarizer ────────────────────────────────────────────────────────────

@rt.function_node
async def summarize_url(url: str) -> str:
    """Fetch a URL and summarise its content using an LLM."""
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(url, follow_redirects=True)
    from bs4 import BeautifulSoup
    text = BeautifulSoup(resp.text, "lxml").get_text(" ", strip=True)[:8000]
    llm = get_llm("url_summarizer")
    result = await llm.ainvoke([{"role": "user", "content": f"Summarise:\n{text}"}])
    return result.content

# ── Reminders ─────────────────────────────────────────────────────────────────

@rt.function_node
async def set_reminder(user_id: str, message: str, fire_at: str) -> str:
    """
    Set a reminder for the user. fire_at must be ISO 8601 format
    (e.g. '2026-03-20T09:00:00').
    """
    conn = await get_db_connection()
    try:
        await conn.execute(
            "INSERT INTO reminders (user_id, message, fire_at) VALUES ($1,$2,$3)",
            user_id, message, fire_at,
        )
    finally:
        await conn.close()
    return f"Reminder set: '{message}' at {fire_at}"

# ── Tool registry ─────────────────────────────────────────────────────────────

BUILTIN_TOOLS = (
    get_weather,
    get_current_datetime,
    web_search,
    search_news,
    get_stock_price,
    wikipedia_search,
    summarize_url,
    set_reminder,
)
```

---

## 5. Agent Nodes — `rt.agent_node`

Each of the 10 agents becomes an `rt.agent_node`. Agents that previously had hand-rolled streaming loops now get streaming for free.

```python
# service/rt_agents.py

import railtracks as rt
from rt_tools import (
    web_search, search_news, get_weather, get_current_datetime,
    get_stock_price, wikipedia_search, summarize_url, set_reminder,
    BUILTIN_TOOLS,
)
from prompts import (
    WINGMAN_GATE_SYSTEM_PROMPT,
    WINGMAN_ASSIST_SYSTEM_PROMPT_TEMPLATE,
    WINGMAN_CONVERSATION_COMPACT_PROMPT,
    WINGMAN_CONVERSATION_END_SUMMARY_PROMPT,
    DASHBOARD_AGENT_PROMPTS,
    FILE_SUMMARIZER_PROMPT,
    PERSONA_GENERATION_SYSTEM_PROMPT,
)

# ─────────────────────────────────────────────────────────────────────────────
# LLM definitions  (LiteLLM model strings, configured via .env)
# ─────────────────────────────────────────────────────────────────────────────

_FLASH_LITE  = rt.llm.LiteLLM("gemini/gemini-flash-lite-latest",  temperature=0.7)
_FLASH_LITE_COLD = rt.llm.LiteLLM("gemini/gemini-flash-lite-latest", temperature=0.2)
_FLASH_LITE_GATE = rt.llm.LiteLLM("gemini/gemini-flash-lite-latest", temperature=0.5,
                                    max_tokens=150)
_FLASH_LITE_SUM  = rt.llm.LiteLLM("gemini/gemini-flash-lite-latest", temperature=0.3,
                                    max_tokens=2000)
_FLASH_LITE_COMP = rt.llm.LiteLLM("gemini/gemini-flash-lite-latest", temperature=0.2,
                                    max_tokens=3000)
_PRO         = rt.llm.LiteLLM("gemini/gemini-3-pro-preview",      temperature=0.9,
                                max_tokens=600)
_PRO_BG      = rt.llm.LiteLLM("gemini/gemini-3-pro-preview",      temperature=0.3)
_FLASH_25    = rt.llm.LiteLLM("gemini/gemini-2.5-flash",          temperature=0.5,
                                max_tokens=1500)

# ─────────────────────────────────────────────────────────────────────────────
# [1] Passive Agent — real-time Q&A
# ─────────────────────────────────────────────────────────────────────────────

passive_agent = rt.agent_node(
    "wingman_passive",
    tool_nodes=(),               # no tools — pure generation
    llm=_FLASH_LITE,
    system_message="",           # built dynamically per-session; see wingman_flow
)

# ─────────────────────────────────────────────────────────────────────────────
# [2] Gate Agent — proactive trigger judge (JSON only)
# ─────────────────────────────────────────────────────────────────────────────

gate_agent = rt.agent_node(
    "wingman_gate",
    tool_nodes=(),
    llm=_FLASH_LITE_GATE,
    system_message=WINGMAN_GATE_SYSTEM_PROMPT,
)

# ─────────────────────────────────────────────────────────────────────────────
# [3] Assist Agent — deep-brain advisor (ReAct with MCP + web tools)
# ─────────────────────────────────────────────────────────────────────────────
# tool_nodes are injected per-request (per-user MCP filtering); see wingman_flow

assist_agent = rt.agent_node(
    "wingman_assist",
    tool_nodes=(web_search,),    # baseline; extended with MCP tools per-request
    llm=_PRO,
    system_message="",           # built dynamically from WINGMAN_ASSIST_SYSTEM_PROMPT_TEMPLATE
)

# ─────────────────────────────────────────────────────────────────────────────
# [4] Compactor Agent — transcript compression
# ─────────────────────────────────────────────────────────────────────────────

compactor_agent = rt.agent_node(
    "wingman_compactor",
    tool_nodes=(),
    llm=_FLASH_LITE_COMP,
    system_message=WINGMAN_CONVERSATION_COMPACT_PROMPT,
)

# ─────────────────────────────────────────────────────────────────────────────
# [5] End-Summary Agent — session recap + memory update
# ─────────────────────────────────────────────────────────────────────────────

end_summary_agent = rt.agent_node(
    "wingman_end_summary",
    tool_nodes=(),
    llm=_FLASH_LITE_SUM,
    system_message=WINGMAN_CONVERSATION_END_SUMMARY_PROMPT,
)

# ─────────────────────────────────────────────────────────────────────────────
# [6] Copilot Agent — text chat with full tool access
# ─────────────────────────────────────────────────────────────────────────────

copilot_agent = rt.agent_node(
    "copilot",
    tool_nodes=BUILTIN_TOOLS,   # + MCP tools added per-request in copilot_flow
    llm=_FLASH_LITE,
    system_message="",           # injected per-session with memory context
)

# ─────────────────────────────────────────────────────────────────────────────
# [7] Insights Agent — extract tasks + memory from transcript
# ─────────────────────────────────────────────────────────────────────────────

insights_agent = rt.agent_node(
    "insights",
    tool_nodes=(),
    llm=rt.llm.LiteLLM("gemini/gemini-2.0-flash-lite", temperature=0.3),
    system_message="Extract structured insights (tasks, memories) from the conversation.",
)

# ─────────────────────────────────────────────────────────────────────────────
# [8] File Summarizer Agent — multimodal file extraction
# ─────────────────────────────────────────────────────────────────────────────

file_summarizer_agent = rt.agent_node(
    "wingman_file_summarizer",
    tool_nodes=(),
    llm=_PRO_BG,
    system_message=FILE_SUMMARIZER_PROMPT,
)

# ─────────────────────────────────────────────────────────────────────────────
# [9] Persona Generator Agent — scenario persona creation
# ─────────────────────────────────────────────────────────────────────────────

persona_gen_agent = rt.agent_node(
    "wingman_persona_gen",
    tool_nodes=(),
    llm=rt.llm.LiteLLM("gemini/gemini-3-pro-preview", temperature=0.7),
    system_message=PERSONA_GENERATION_SYSTEM_PROMPT,
)

# ─────────────────────────────────────────────────────────────────────────────
# [10] Dashboard Agent — home-screen card generation (ReAct with web search)
# ─────────────────────────────────────────────────────────────────────────────

dashboard_agent = rt.agent_node(
    "dashboard",
    tool_nodes=(web_search,),
    llm=_FLASH_25,
    system_message=DASHBOARD_AGENT_PROMPTS,
)
```

---

## 6. Flow Definitions — `rt.Flow`

Flows are **plain Python**. No graph DSL — branching, looping, and async fan-out are expressed with `if`, `while`, and `asyncio.create_task`.

### 6.1 Wingman Flow

```python
# service/flows/wingman_flow.py

import asyncio, json, re, time
import railtracks as rt
from rt_agents import (
    passive_agent, gate_agent, assist_agent,
    compactor_agent, end_summary_agent,
)
from rt_tools import web_search
from rt_mcp import get_mcp_tools_for_user    # see §8
from conversation_record import ConversationRecord
from database import get_db_connection
from prompts import build_passive_system, build_assist_system

# ── Passive sub-flow ─────────────────────────────────────────────────────────

async def run_passive(session, request):
    """Stream a passive response for a direct user question."""
    system = build_passive_system(
        user_name=session.user_name,
        persona=session.generated_persona,
        format_rules=session.format_rules,
        file_summary=session.file_summary,
    )
    user_msg = session.record.get_passive_context()

    # rt.Flow: single agent node, streaming
    flow = rt.Flow(
        name="passive",
        entry_point=passive_agent.with_config(system_message=system),
    )

    async for chunk in flow.stream(user_msg):
        yield chunk                          # chunk.text → gRPC TokenChunk

    session.record.fill_placeholder("passive", flow.last_output)

    if session.record.needs_compaction():
        await run_compactor(session)

# ── Proactive sub-flow ───────────────────────────────────────────────────────

async def run_proactive(session, metadata):
    """Gate → (optional nudge + assist) pipeline."""

    # ── Gate ──────────────────────────────────────────────────────────────────
    gate_flow = rt.Flow(name="gate", entry_point=gate_agent)
    gate_input = session.record.get_proactive_context() + f"\n\nmetadata: {json.dumps(metadata)}"

    gate_raw = await gate_flow.invoke(gate_input)
    gate_result = _parse_gate_json(gate_raw)

    if not gate_result.get("trigger"):
        return                               # gate says no — do nothing

    # ── Nudge delivered immediately ───────────────────────────────────────────
    nudge = gate_result.get("user_nudge", "")
    if nudge:
        yield rt.Token(nudge)               # → gRPC → iOS TTS (instant)

    # ── Assist (ReAct, MCP tools per user) ───────────────────────────────────
    mcp_tools = await get_mcp_tools_for_user(session.user_id)
    all_tools = (web_search,) + tuple(mcp_tools)

    system = build_assist_system(gate_result, session.conversation_background,
                                  session.language, session.user_name)
    user_msg = session.record.get_proactive_context()

    assist_flow = rt.Flow(
        name="assist",
        entry_point=assist_agent.with_tools(all_tools).with_config(system_message=system),
    )

    async for chunk in assist_flow.stream(user_msg):
        yield chunk                          # token or tool_status

    session.record.fill_placeholder("assist", assist_flow.last_output)
    session.last_assist_push = time.time()

    if session.record.needs_compaction():
        await run_compactor(session)

# ── Compactor ─────────────────────────────────────────────────────────────────

async def run_compactor(session):
    flow = rt.Flow(name="compactor", entry_point=compactor_agent)
    compacted = await flow.invoke(session.record.get_compact_input())
    session.record.replace_with_compact(compacted)

# ── End-summary (on disconnect) ───────────────────────────────────────────────

async def run_end_summary(session):
    existing_memory = await _fetch_user_memory(session.user_id)
    human = (
        f"<existing_user_memory>\n{existing_memory}\n</existing_user_memory>\n\n"
        f"<conversation_transcript>\n{session.record.get_compact_input()}\n</conversation_transcript>"
    )

    flow = rt.Flow(name="end_summary", entry_point=end_summary_agent)
    output = await flow.invoke(human)

    title   = _xml(output, "conversation_title")
    recap   = _xml(output, "conversation_recap")
    memory  = _xml(output, "user_memory")

    await _store_recap(session, title, recap)
    await _upsert_memory(session.user_id, memory)
    await _send_silent_push(session.user_id, session.session_id, title, recap)

    # Trigger dashboard refresh
    from flows.dashboard_flow import run_dashboard
    asyncio.create_task(run_dashboard(session.user_id))

# ── Helpers ───────────────────────────────────────────────────────────────────

def _parse_gate_json(raw: str) -> dict:
    raw = raw.strip().lstrip("```json").rstrip("```").strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"trigger": False, "user_nudge": ""}

def _xml(text: str, tag: str) -> str:
    m = re.search(rf"<{tag}>(.*?)</{tag}>", text, re.DOTALL)
    return m.group(1).strip() if m else ""
```

### 6.2 Background Flow

```python
# service/flows/background_flow.py

import railtracks as rt
from rt_agents import file_summarizer_agent, persona_gen_agent
from database import get_db_connection

async def run_background_pipeline(background_id: str, conversation_background: str,
                                   attachments: list | None = None) -> None:
    """
    Async pipeline triggered on background create/update.
    Flows are just Python — sequential steps with a conditional branch.
    """

    file_summary = ""

    # ── Step 1: File summarizer (only if attachments present) ─────────────────
    if attachments:
        multimodal_input = _build_multimodal_input(attachments)

        file_flow = rt.Flow(
            name="file_summarizer",
            entry_point=file_summarizer_agent,
        )
        file_summary = await file_flow.invoke(multimodal_input)

        await _store_field(background_id, "file_summary", file_summary)

    # ── Step 2: Persona generator (always) ────────────────────────────────────
    persona_input = conversation_background
    if file_summary:
        persona_input += f"\n\nReference material summary:\n{file_summary}"

    persona_flow = rt.Flow(
        name="persona_generator",
        entry_point=persona_gen_agent,
    )
    persona = await persona_flow.invoke(persona_input)

    await _store_field(background_id, "generated_persona", persona)
    await _set_status(background_id, "ready")

def _build_multimodal_input(attachments: list) -> str:
    # Railtracks passes multimodal content via structured string with data URIs
    parts = ["Extract all facts from the following files:"]
    for att in attachments:
        parts.append(f"[file: data:{att['mime_type']};base64,{att['data']}]")
    return "\n".join(parts)
```

### 6.3 Dashboard Flow

```python
# service/flows/dashboard_flow.py

import re
import railtracks as rt
from rt_agents import dashboard_agent
from database import get_db_connection
from prompts import format_current_time

_CARD_RE = re.compile(r"\[(reminder|social|insight|discover|tip)]\s*(.+)")

async def run_dashboard(user_id: str) -> list[dict]:
    """Generate and cache dashboard cards. Called post-session and daily at 06:00."""

    memory_text, recaps_text = await _fetch_inputs(user_id)

    if not memory_text and not recaps_text:
        cards = _default_tips()
        await _store_cards(user_id, cards)
        return cards

    human = (
        f"Current time: {format_current_time()}\n\n"
        f"User memory:\n{memory_text or '(none yet)'}\n\n"
        f"Recent session recaps (last 7 days):\n{recaps_text or '(none)'}"
    )

    # rt.Flow with web_search tool — Railtracks handles the ReAct loop internally
    flow = rt.Flow(name="dashboard", entry_point=dashboard_agent)
    output = await flow.invoke(human)

    cards = [
        {"type": m.group(1), "content": m.group(2).strip()}
        for line in output.strip().splitlines()
        if (m := _CARD_RE.match(line.strip()))
    ][:6]

    if not cards:
        return []

    await _store_cards(user_id, cards)
    return cards
```

### 6.4 Copilot Flow

```python
# service/flows/copilot_flow.py

import railtracks as rt
from rt_agents import copilot_agent, insights_agent
from rt_tools import BUILTIN_TOOLS
from rt_mcp import get_mcp_tools_for_user
from insights import retrieve_insights, store_insights
from database import get_db_connection

async def run_copilot(session, user_message: str):
    """
    Bidirectional chat with full tool access.
    Streaming tokens and tool status events yielded to gRPC adapter.
    """

    # 1. Retrieve relevant memories (pgvector similarity)
    memories = await retrieve_insights(session.user_id, user_message)

    # 2. Build system prompt with memory context
    system = _build_system(session, memories)

    # 3. Assemble per-user tool set
    mcp_tools  = await get_mcp_tools_for_user(session.user_id)
    all_tools  = BUILTIN_TOOLS + tuple(mcp_tools)

    # 4. Run copilot flow (handles two-pass tool execution internally)
    flow = rt.Flow(
        name="copilot",
        entry_point=copilot_agent.with_tools(all_tools).with_config(system_message=system),
    )

    async for chunk in flow.stream(user_message, history=session.history):
        yield chunk                          # rt.Token or rt.ToolStatus

    # 5. Update session history
    session.history.append({"role": "user",      "content": user_message})
    session.history.append({"role": "assistant",  "content": flow.last_output})
    session.accumulated_words += len(user_message.split())

    # 6. Threshold check → async insight extraction
    if session.accumulated_words >= 24_000:
        import asyncio
        asyncio.create_task(_run_insights(session))
        session.accumulated_words = 0

async def _run_insights(session):
    from flows.insights_flow import run_insights
    await run_insights(session.user_id, session.history)
```

---

## 7. LLM Provider via LiteLLM

Railtracks bundles LiteLLM as its LLM gateway. This replaces the custom `llm_provider.py` + `providers.json` system. All providers are addressed by a `provider/model` string in `.env`.

```
# .env  — model role assignments (replaces providers.json)

RT_LLM_PASSIVE=gemini/gemini-flash-lite-latest
RT_LLM_GATE=gemini/gemini-flash-lite-latest
RT_LLM_ASSIST=gemini/gemini-3-pro-preview
RT_LLM_COMPACTOR=gemini/gemini-flash-lite-latest
RT_LLM_END_SUMMARY=gemini/gemini-flash-lite-latest
RT_LLM_COPILOT=gemini/gemini-flash-lite-latest
RT_LLM_INSIGHTS=gemini/gemini-2.0-flash-lite
RT_LLM_FILE_SUM=gemini/gemini-3-pro-preview
RT_LLM_PERSONA=gemini/gemini-3-pro-preview
RT_LLM_DASHBOARD=gemini/gemini-2.5-flash

# Provider API keys (LiteLLM reads these automatically)
GEMINI_API_KEY=...
ANTHROPIC_API_KEY=...          # optional — switch any role to claude-*
DEEPSEEK_API_KEY=...           # optional — switch any role to deepseek/*
MOONSHOT_API_KEY=...           # optional — moonshot/kimi-k2.5
```

**Switching a single agent to Claude** — one line change, no code touch:

```bash
# .env
RT_LLM_ASSIST=anthropic/claude-sonnet-4-6
```

```python
# rt_agents.py  — reads from env
import os
_PRO = rt.llm.LiteLLM(os.getenv("RT_LLM_ASSIST", "gemini/gemini-3-pro-preview"),
                       temperature=0.9, max_tokens=600)
```

**Supported LiteLLM model strings for this project:**

| Provider | Model string example |
|---|---|
| Google Gemini | `gemini/gemini-flash-lite-latest` |
| Anthropic | `anthropic/claude-sonnet-4-6` |
| DeepSeek | `deepseek/deepseek-chat` |
| Moonshot/Kimi | `moonshot/kimi-k2.5` |
| Qwen | `together_ai/qwen-plus` |
| Grok (xAI) | `xai/grok-4-0709` |
| Ollama (local) | `ollama/llama3.2` |

---

## 8. MCP Tools Integration

Railtracks has native MCP client support via `rt.mcp_client`. This replaces the 370-line `mcp_manager.py`.

```python
# service/rt_mcp.py

import railtracks as rt
import json, os
from pathlib import Path
from functools import lru_cache

# Load server definitions (same servers.json schema as before)
_SERVERS_JSON = Path(__file__).parent / "servers.json"

@lru_cache(maxsize=1)
def _load_server_specs() -> list[dict]:
    with open(_SERVERS_JSON) as f:
        return json.load(f)["servers"]

# Module-level MCP client (initialised once at startup)
_mcp_client: rt.MCPClient | None = None

async def init_mcp(app):
    """Called at FastAPI startup."""
    global _mcp_client
    specs = _load_server_specs()
    _mcp_client = rt.MCPClient()
    for spec in specs:
        try:
            await _mcp_client.connect(
                name=spec["name"],
                command=spec["command"],
                args=spec.get("args", []),
                env={k: os.path.expandvars(v) for k, v in spec.get("env", {}).items()},
            )
        except Exception as e:
            print(f"[MCP] Failed to connect {spec['name']}: {e}")

async def get_mcp_tools_for_user(user_id: str) -> tuple:
    """Return rt.function_node-compatible tools enabled for this user."""
    if not _mcp_client:
        return ()
    enabled = await _enabled_servers_for_user(user_id)
    return _mcp_client.get_tool_nodes(server_names=enabled)

async def shutdown_mcp():
    if _mcp_client:
        await _mcp_client.disconnect_all()

async def _enabled_servers_for_user(user_id: str) -> list[str]:
    from database import get_db_connection
    conn = await get_db_connection()
    try:
        rows = await conn.fetch(
            "SELECT server_name FROM mcp_server_config "
            "WHERE user_id = $1 AND enabled = TRUE",
            user_id,
        )
        return [r["server_name"] for r in rows]
    finally:
        await conn.close()
```

**Before vs after** — `mcp_manager.py` replacement:

```
BEFORE                              AFTER
══════════════════════════════      ═══════════════════════════════════════
mcp_manager.py  (373 lines)    →   rt_mcp.py  (~60 lines)
MCPManager singleton           →   rt.MCPClient()
_build_pydantic_model()        →   rt handles JSON Schema → tool wrapping
call_mcp_tool() with timeout   →   rt.MCPClient handles timeouts
_reconnect_server() with lock  →   rt.MCPClient auto-reconnects
get_tools_for_user() cache     →   30s LRU cache in rt_mcp.py (same)
```

---

## 9. Observability

Railtracks ships a built-in local observability layer — no Langsmith subscription, no external SaaS, no signup.

```python
# service/main.py  — enable Railtracks tracing at startup

import railtracks as rt

rt.configure(
    tracing=True,                          # enables step-by-step execution traces
    trace_dir="./traces",                  # local trace storage
    log_level="INFO",
)
```

What each agent emits automatically:

```
[wingman_gate]     INVOKE  input=<proactive_context>
[wingman_gate]     TOKEN   "{"
[wingman_gate]     TOKEN   "trigger"
  ...
[wingman_gate]     DONE    output={"trigger":true,"user_nudge":"Let me think..."}
                   latency=312ms  tokens_in=1840  tokens_out=48

[wingman_assist]   INVOKE  input=<proactive_context>
[wingman_assist]   TOOL    web_search  args={"query":"global GDP 2025 figures"}
[wingman_assist]   RESULT  web_search  chars=1240  latency=1340ms
[wingman_assist]   TOKEN   "The correct figure"
[wingman_assist]   TOKEN   " is approximately 3.8B"
  ...
[wingman_assist]   DONE    output="The correct figure is..."
                   latency=2410ms  tokens_in=2100  tokens_out=87  tool_calls=1
```

**Local visualiser** — start with:

```bash
railtracks visualize --trace-dir ./traces
# opens http://localhost:7654
```

Shows per-flow execution timelines, token counts, tool call chains, and error traces across all 10 agents.

**Replacing debug_logger.py** — the three custom log channels collapse to one:

```python
# BEFORE
from debug_logger import llm_log, agent_log, first10
agent_log.info("[TRIGGER] GATE  session=%s", session.session_id)
llm_log.info("[INPUT] GATE ...\n%s", messages)
agent_log.info("[RESPOND] GATE  time=%.2fs  trigger=%s", elapsed, trigger)

# AFTER  — emitted automatically by rt.Flow / rt.agent_node
# Nothing to write. Railtracks captures input, output, latency, tokens per node.
```

---

## 10. gRPC Streaming Adapter

The gRPC servicers (`WingmanServicer`, `CopilotServicer`) receive Railtracks stream chunks and translate them to protobuf messages.

```python
# service/rt_grpc_adapter.py

import railtracks as rt
from proto.assistant import assistant_pb2

def rt_chunk_to_proto(chunk: rt.Chunk) -> assistant_pb2.WingmanResponse | None:
    """Translate a Railtracks stream chunk to a WingmanResponse protobuf."""

    if isinstance(chunk, rt.Token):
        return assistant_pb2.WingmanResponse(
            token=assistant_pb2.TokenChunk(text=chunk.text)
        )

    elif isinstance(chunk, rt.ToolStatus):
        return assistant_pb2.WingmanResponse(
            status=assistant_pb2.StatusUpdate(tool_name=chunk.tool_name)
        )

    elif isinstance(chunk, rt.Done):
        return assistant_pb2.WingmanResponse(
            done=assistant_pb2.DoneSignal()
        )

    elif isinstance(chunk, rt.Error):
        return assistant_pb2.WingmanResponse(
            error=assistant_pb2.ErrorMessage(message=chunk.message)
        )

    return None   # internal Railtracks events — skip


# Usage in WingmanServicer:

async def _handle_passive(self, request):
    session = self._get_session(request)
    async for chunk in run_passive(session, request):
        proto = rt_chunk_to_proto(chunk)
        if proto:
            yield proto

async def _handle_proactive(self, request):
    session = self._get_session(request)
    async for chunk in run_proactive(session, request.metadata):
        proto = rt_chunk_to_proto(chunk)
        if proto:
            yield proto
```

**Chunk type mapping:**

```
Railtracks chunk        protobuf field              iOS client action
────────────────────    ──────────────────────────  ────────────────────────
rt.Token(text)          token: TokenChunk           AVSpeechSynthesizer.speak()
rt.ToolStatus(name)     status: StatusUpdate        show "Searching..." badge
rt.Done()               done: DoneSignal            hide indicator
rt.Error(msg)           error: ErrorMessage         show toast
```

---

## 11. Migration Plan

```
Phase 1 — Tools  (1 day, zero risk)
────────────────────────────────────
  pip install railtracks
  Create rt_tools.py: port @langchain.tool → @rt.function_node
  Run side-by-side: both tool registries active
  Verify tool outputs are identical

Phase 2 — Dashboard agent  (1 day, isolated)
─────────────────────────────────────────────
  Replace dashboard_agent.py with flows/dashboard_flow.py
  dashboard flow is fully async, no gRPC involvement
  A/B test: run old and new, compare card output

Phase 3 — Background flows  (1 day, no live traffic)
──────────────────────────────────────────────────────
  Replace HTTP background endpoint handlers
  file_summarizer + persona_gen → background_flow.py
  Test by creating a background via API

Phase 4 — Copilot  (2 days)
─────────────────────────────
  Replace copilot_handler.py with copilot_flow.py + rt_grpc_adapter.py
  MCP manager → rt_mcp.py (parallel run, same servers.json)
  Full integration test against copilot WebSocket

Phase 5 — Wingman  (2 days)
─────────────────────────────
  Replace wingman_handler.py with wingman_flow.py + rt_grpc_adapter.py
  Gate, passive, assist, compactor, end-summary all in one flow file
  Regression: full proactive path with web search

Phase 6 — LLM provider  (0.5 day)
───────────────────────────────────
  Replace llm_provider.py + providers.json with LiteLLM env vars
  All rt.llm.LiteLLM("role") calls read from RT_LLM_* env vars
  Delete providers.json, llm_provider.py

Phase 7 — Observability cleanup  (0.5 day)
────────────────────────────────────────────
  Delete debug_logger.py, agent_log, llm_log references
  Verify rt trace_dir captures all 10 agents
  Start local visualiser, confirm traces appear

Files deleted after migration:
  service/search_agent.py          (replaced by rt.agent_node + rt.Flow)
  service/mcp_manager.py           (replaced by rt_mcp.py using rt.MCPClient)
  service/llm_provider.py          (replaced by rt.llm.LiteLLM)
  service/llm_providers/providers.json
  service/debug_logger.py          (replaced by rt.configure(tracing=True))
  service/tools.py                 (replaced by service/rt_tools.py)
```

---

## 12. File Structure After Migration

```
service/
├── main.py                    startup: init rt, mcp, grpc
├── rt_tools.py                @rt.function_node tool registry  (was tools.py)
├── rt_agents.py               rt.agent_node definitions (all 10 agents)
├── rt_mcp.py                  rt.MCPClient wrapper  (was mcp_manager.py)
├── rt_grpc_adapter.py         rt.Chunk → protobuf translator
│
├── flows/
│   ├── wingman_flow.py        passive + gate + assist + compactor + end_summary
│   ├── copilot_flow.py        copilot + insights
│   ├── dashboard_flow.py      dashboard agent + card parsing
│   ├── background_flow.py     file_summarizer + persona_gen
│   └── insights_flow.py       insight extraction + pgvector storage
│
├── wingman_handler.py         gRPC servicer (thin — delegates to wingman_flow)
├── copilot_handler.py         gRPC servicer (thin — delegates to copilot_flow)
├── conversation_record.py     unchanged — per-session event log
├── insights.py                unchanged — pgvector storage/retrieval
├── database.py                unchanged
├── schedulers.py              unchanged
├── http_endpoints.py          unchanged (background endpoint calls background_flow)
├── memory.py                  unchanged
├── prompts/                   unchanged
├── proto/                     unchanged
└── servers.json               unchanged — MCP server definitions

DELETED:
  search_agent.py
  mcp_manager.py
  llm_provider.py
  llm_providers/providers.json
  debug_logger.py
  tools.py  (superseded by rt_tools.py)
```

---

## 13. Configuration

```bash
# Install
pip install railtracks railtracks[cli]

# Add to requirements.txt
railtracks>=1.3.1

# .env additions
RT_LLM_PASSIVE=gemini/gemini-flash-lite-latest
RT_LLM_GATE=gemini/gemini-flash-lite-latest
RT_LLM_ASSIST=gemini/gemini-3-pro-preview
RT_LLM_COMPACTOR=gemini/gemini-flash-lite-latest
RT_LLM_END_SUMMARY=gemini/gemini-flash-lite-latest
RT_LLM_COPILOT=gemini/gemini-flash-lite-latest
RT_LLM_INSIGHTS=gemini/gemini-2.0-flash-lite
RT_LLM_FILE_SUM=gemini/gemini-3-pro-preview
RT_LLM_PERSONA=gemini/gemini-3-pro-preview
RT_LLM_DASHBOARD=gemini/gemini-2.5-flash

# service/main.py
import railtracks as rt
rt.configure(tracing=True, trace_dir="./traces", log_level="INFO")

# Start observability visualiser (separate terminal)
railtracks visualize --trace-dir ./traces
# → http://localhost:7654
```
