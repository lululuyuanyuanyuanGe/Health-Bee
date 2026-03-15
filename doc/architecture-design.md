# CueBee — Agentic System Architecture Design

> **Version:** 1.0
> **Last updated:** March 2026
> A real-time AI conversation assistant delivered through earbuds. Ten specialised agents, orchestrated by LangGraph, running across three independent pipelines.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Top-Level Architecture](#2-top-level-architecture)
3. [The Ten Agents](#3-the-ten-agents)
4. [Pipeline 1 — Wingman (Real-Time)](#4-pipeline-1--wingman-real-time)
5. [Pipeline 2 — Copilot (Text Chat)](#5-pipeline-2--copilot-text-chat)
6. [Pipeline 3 — Background & Cross-Session](#6-pipeline-3--background--cross-session)
7. [LangGraph Orchestration](#7-langgraph-orchestration)
8. [MCP Tool Ecosystem](#8-mcp-tool-ecosystem)
9. [ConversationRecord — Shared Memory Bus](#9-conversationrecord--shared-memory-bus)
10. [Persistence & Data Model](#10-persistence--data-model)
11. [Scheduler & Push System](#11-scheduler--push-system)
12. [LLM Provider Layer](#12-llm-provider-layer)
13. [End-to-End Request Trace](#13-end-to-end-request-trace)
14. [Design Decisions & Trade-offs](#14-design-decisions--trade-offs)

---

## 1. Executive Summary

CueBee is a **discreet AI conversation assistant** that listens to live conversations through earbuds and proactively coaches the user — whispering factual corrections, strategic cues, and ready-to-speak replies — without the other person knowing.

### What makes the system complex

| Dimension | Detail |
|---|---|
| **10 specialised agents** | Each with a dedicated model, temperature, token budget, and prompt |
| **Three concurrent pipelines** | Wingman (real-time), Copilot (text chat), Background (async) |
| **LangGraph orchestration** | ReAct loops with tool use inside two of the pipelines |
| **MCP tool ecosystem** | Pluggable external tools without code changes |
| **Live streaming** | Token-by-token streaming through gRPC → Go gateway → iOS TTS |
| **Multi-tier memory** | Vector embeddings + persistent memory + session recaps + dashboard cache |
| **Anti-spam & coordination** | Gate model prevents expensive agent activations; cooldowns, thresholds |

### Cost envelope (per 15-min session)

```
On-device STT (Apple SpeechAnalyzer)  : $0.000
On-device TTS (AVSpeechSynthesizer)    : $0.000
Gemini API (all agents combined)       : ~$0.003
                                         ──────
Total (default)                        : ~$0.003/session

Optional enhanced TTS (Inworld)        : +$0.015
Total (premium)                        : ~$0.018/session
```

---

## 2. Top-Level Architecture

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                              iOS CLIENT                                      ║
║                                                                              ║
║  ┌─────────────────────┐   ┌─────────────────────┐   ┌──────────────────┐  ║
║  │ Apple SpeechAnalyzer│   │  AVSpeechSynthesizer │   │  Inworld TTS     │  ║
║  │ (Neural Engine STT) │   │  (default, on-device)│   │  (opt-in, $0.005 │  ║
║  │  on-device · free   │   │  free                │   │   /1k chars)     │  ║
║  └─────────┬───────────┘   └─────────▲────────────┘   └────────▲─────────┘  ║
║            │ text utterances          │ tokens / audio            │           ║
║            │ VAD triggered            │                           │           ║
╚════════════│══════════════════════════│═══════════════════════════│═══════════╝
             │ WebSocket JSON           │                           │
             │ Bearer / Firebase JWT    │                           │
             ▼                         │                           │
╔════════════════════════════════════════════════════════════════════════════════╗
║                          GO GATEWAY  :5000                                    ║
║                                                                                ║
║  ┌──────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐  ║
║  │    Auth      │  │  Rate Limiting  │  │   WS Upgrade    │  │ HTTP Proxy │  ║
║  │  Firebase JWT│  │  per-user slide │  │  /ws/wingman    │  │ /api/*     │  ║
║  │  API key     │  │  window in-mem  │  │  /ws/copilot    │  │            │  ║
║  │              │  │  configurable   │  │  /ws/stt        │  │            │  ║
║  │  →X-Verified-│  │  per-user over- │  │                 │  │            │  ║
║  │   User-ID    │  │  rides via admin│  │                 │  │            │  ║
║  └──────────────┘  └─────────────────┘  └────────┬────────┘  └─────┬──────┘  ║
╚══════════════════════════════════════════════════│══════════════════│══════════╝
                                                   │ gRPC             │ HTTP
                                    ┌──────────────┘                  │
                                    ▼                                  ▼
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     PYTHON SERVICE  :5001  (FastAPI + gRPC)                  ║
║                                                                               ║
║  ┌────────────────────────────────────────────────────────────────────────┐  ║
║  │  PIPELINE 1: WINGMAN  (WingmanServicer — gRPC streaming)              │  ║
║  │                                                                        │  ║
║  │  passive ──► [1] Passive Agent                                         │  ║
║  │                                                                        │  ║
║  │  proactive ─► [2] Gate Agent ──trigger──► [3] Assist Agent            │  ║
║  │                                                (LangGraph ReAct)      │  ║
║  │  on word threshold ─► [4] Compactor Agent                             │  ║
║  │  on disconnect ─────► [5] End-Summary Agent ──► dashboard trigger     │  ║
║  └────────────────────────────────────────────────────────────────────────┘  ║
║                                                                               ║
║  ┌────────────────────────────────────────────────────────────────────────┐  ║
║  │  PIPELINE 2: COPILOT  (CopilotServicer — gRPC bidi streaming)         │  ║
║  │                                                                        │  ║
║  │  chat ──► [6] Copilot Agent  (LangChain tool binding + MCP tools)     │  ║
║  │  on threshold ──► [7] Insights Agent  (async task)                    │  ║
║  └────────────────────────────────────────────────────────────────────────┘  ║
║                                                                               ║
║  ┌────────────────────────────────────────────────────────────────────────┐  ║
║  │  PIPELINE 3: BACKGROUND  (async tasks + cron)                         │  ║
║  │                                                                        │  ║
║  │  on background create/update ──► [8]  File Summarizer Agent           │  ║
║  │                             ──► [9]  Persona Generator Agent          │  ║
║  │  post end-summary / 06:00 cron ─► [10] Dashboard Agent                │  ║
║  │                                         (LangGraph ReAct)             │  ║
║  └────────────────────────────────────────────────────────────────────────┘  ║
║                                                                               ║
║  ┌────────────────────────────────────────────────────────────────────────┐  ║
║  │  SHARED INFRASTRUCTURE                                                 │  ║
║  │                                                                        │  ║
║  │  MCPManager  ·  LLM Provider  ·  ConversationRecord  ·  Schedulers    │  ║
║  └────────────────────────────────────────────────────────────────────────┘  ║
╚═══════════════════════════════════════════════════════════════════════════════╝
             │                                      │
             ▼                                      ▼
    ┌─────────────────┐                   ┌──────────────────────┐
    │   PostgreSQL    │                   │     Gemini API        │
    │   + pgvector    │                   │                       │
    │                 │                   │  flash-lite  ← [1][2] │
    │  users          │                   │  flash-lite  ← [4][5] │
    │  user_memory    │                   │  pro         ← [3]   │
    │  user_insights  │                   │  flash-lite  ← [6][7] │
    │  session_recaps │                   │  pro         ← [8][9] │
    │  dashboard_cache│                   │  2.5-flash   ← [10]  │
    │  wingman_bg     │                   └──────────────────────┘
    │  reminders      │
    │  push_tokens    │
    │  mcp_server_cfg │
    └─────────────────┘
```

---

## 3. The Ten Agents

```
┌────┬──────────────────────────┬─────────────────────────┬──────────┬────────┬────────────────┐
│ #  │ Agent                    │ Role                     │ Model    │  Temp  │ Max Tokens     │
├────┼──────────────────────────┼─────────────────────────┼──────────┼────────┼────────────────┤
│  1 │ wingman_passive          │ Real-time Q&A            │ flash-lite│ 0.7   │ (default)      │
│  2 │ wingman_gate             │ Proactive trigger judge  │ flash-lite│ 0.5   │ 150            │
│  3 │ wingman_assist           │ Deep-brain advisor       │ pro       │ 0.9   │ 600            │
│  4 │ wingman_compactor        │ Transcript compaction    │ flash-lite│ 0.2   │ 3 000          │
│  5 │ wingman_end_summary      │ Session recap + memory   │ flash-lite│ 0.3   │ 2 000          │
│  6 │ copilot                  │ Text chat with tools     │ flash-lite│ 0.7   │ (default)      │
│  7 │ insights                 │ Extract tasks/memory     │ flash-lite│ 0.3   │ (structured)   │
│  8 │ file_summarizer          │ Multimodal file extract  │ pro       │ 0.3   │ (default)      │
│  9 │ persona_generator        │ Scenario persona craft   │ pro       │ 0.7   │ (default)      │
│ 10 │ dashboard                │ Home-screen card gen     │ 2.5-flash │ 0.5   │ 1 500          │
├────┼──────────────────────────┼─────────────────────────┼──────────┼────────┼────────────────┤
│    │ Tool access              │                                                               │
│  3 │ wingman_assist           │ MCP tools (per-user), web search                             │
│  6 │ copilot                  │ ALL built-in tools + MCP tools (per-user)                    │
│ 10 │ dashboard                │ web_search (DuckDuckGo, always available)                    │
└────┴──────────────────────────┴────────────────────────────────────────────────────────────┘

Agents 3, 6, 10 run inside a LangGraph ReAct graph.
Agents 1, 2, 4, 5, 7, 8, 9 are plain LLM calls (no tool loop).
```

---

## 4. Pipeline 1 — Wingman (Real-Time)

The Wingman pipeline is the core product. It runs inside a persistent WebSocket session and processes every utterance through two parallel sub-pipelines.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  WINGMAN PIPELINE  —  WingmanServicer (gRPC)                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

Client sends WS message: { type: "passive" | "proactive", ... }
                │
                ▼
    ┌───────────────────────┐
    │  _sync_session_config │  first call only per session
    │  • fetch user_name    │  (cached in MonitorSession)
    │  • fetch persona      │
    │  • fetch file_summary │
    └───────────┬───────────┘
                │
       type? ───┴────────────────────────────────────────────────────┐
       │                                                             │
  "passive"                                                     "proactive"
       │                                                             │
       ▼                                                             ▼
┌──────────────────────────────────┐          ┌────────────────────────────────────────────┐
│  PASSIVE SUB-PIPELINE            │          │  PROACTIVE SUB-PIPELINE                    │
│                                  │          │                                            │
│  record.append_user_query()      │          │  record.append_transcript(utterances)      │
│                                  │          │                                            │
│  get_passive_messages():         │          │  Anti-spam guard:                          │
│  ┌───────────────────────────┐   │          │  ├─ MIN_NEW_CHARS ≥ 20                     │
│  │ System:                   │   │          │  ├─ cooldown ≥ 60s since last assist       │
│  │  user_name                │   │          │  ├─ max 10 assists per session             │
│  │  + generated_persona      │   │          │  └─ session_mode check                    │
│  │  + PASSIVE_FORMAT_RULES   │   │          │          │ passes                          │
│  │    [session_mode][mode]   │   │          │          ▼                                 │
│  │  + file_summary           │   │          │  ┌───────────────────────────────────┐     │
│  │ Human:                    │   │          │  │  GATE AGENT  [2]                  │     │
│  │  get_passive_context()    │   │          │  │  gemini-flash-lite · temp 0.5     │     │
│  │  (compact + transcript    │   │          │  │  max 150 tokens                   │     │
│  │   + user_query            │   │          │  │                                   │     │
│  │   + passive AI history)   │   │          │  │  System:                          │     │
│  └───────────────────────────┘   │          │  │   user_name                       │     │
│                                  │          │  │   + WINGMAN_GATE_SYSTEM_PROMPT    │     │
│  AGENT 1 — wingman_passive       │          │  │   + conversation_background       │     │
│  gemini-flash-lite · temp 0.7    │          │  │  Human:                           │     │
│  llm.astream(messages)           │          │  │   get_proactive_context()         │     │
│                                  │          │  │   + metadata:                     │     │
│  ┌────────────────────────────┐  │          │  │     silence_secs                  │     │
│  │ yield token chunks         │  │          │  │     last_assist_elapsed            │     │
│  │ → gRPC WingmanResponse     │  │          │  │     context_keywords              │     │
│  │ → Go gateway               │  │          │  └──────────────┬────────────────────┘     │
│  │ → iOS TTS speaks           │  │          │                 │                          │
│  └────────────────────────────┘  │          │  JSON: {trigger, user_nudge}               │
│                                  │          │                 │                          │
│  on complete:                    │          │  trigger=false  ──────────────► done       │
│  record.fill_placeholder()       │          │                 │ trigger=true             │
│  compact check                   │          │                 ▼                          │
└──────────────────────────────────┘          │  push user_nudge → TTS immediately         │
                                              │  (buys time while assist thinks)           │
                                              │                 │                          │
                                              │  ┌─────────────▼────────────────────────┐ │
                                              │  │  ASSIST AGENT  [3]  (LangGraph ReAct)│ │
                                              │  │  gemini-pro · temp 0.9 · max 600 tok │ │
                                              │  │                                      │ │
                                              │  │  tools = mcp.get_tools_for_user()    │ │
                                              │  │  agent = create_react_agent(llm,     │ │
                                              │  │            tools)                    │ │
                                              │  │                                      │ │
                                              │  │  stream_agent_response()             │ │
                                              │  │  → astream_events(version="v2")      │ │
                                              │  │                                      │ │
                                              │  │  Output modes:                       │ │
                                              │  │  • speak_as_user — verbatim TTS      │ │
                                              │  │  • whisper       — private coaching  │ │
                                              │  └─────────────────────────────────────┘ │
                                              │                 │                          │
                                              │  stream tokens → gRPC → gateway → iOS     │
                                              │                 │                          │
                                              │  record.fill_placeholder("assist", ...)   │
                                              │  compact check                             │
                                              └────────────────────────────────────────────┘

─────────────────────────────────────────────────────────────────────────────────
ON WORD THRESHOLD (≥ 24,000 words ≈ 32k tokens)
─────────────────────────────────────────────────────────────────────────────────

  record.needs_compaction() == True
        │
        ▼
  COMPACTOR AGENT  [4]
  gemini-flash-lite · temp 0.2 · max 3000 tokens
        │
  Input:  get_compact_input()  (all entries, full context)
  Output: single compressed summary
        │
  ConversationRecord.entries = [CompactEntry(summary)]
  (verbatim recent turns preserved in the compact text)

─────────────────────────────────────────────────────────────────────────────────
ON WEBSOCKET DISCONNECT
─────────────────────────────────────────────────────────────────────────────────

  WingmanDisconnect()
        │
        ├─ asyncio.create_task(analyze_conversation_chunk())
        │       │
        │       ▼
        │   INSIGHTS AGENT  [7]
        │   (extract user_tasks + user_memory → pgvector)
        │
        └─ asyncio.create_task(_run_end_summary())
                │
                ▼
          END-SUMMARY AGENT  [5]
          gemini-flash-lite · temp 0.3 · max 2000 tokens
                │
          Input:  get_compact_input()  +  existing_user_memory
          Output: XML tags
            <conversation_title>...</conversation_title>
            <conversation_recap>...</conversation_recap>
            <user_memory>...</user_memory>
                │
          ├─ store → session_recaps (PostgreSQL)
          ├─ store → user_memory (PostgreSQL)
          ├─ send_silent_push() → APNs → wake iOS client
          │
          └─ asyncio.create_task(run_dashboard_agent())
                    │
                    ▼
              DASHBOARD AGENT  [10]
              (Pipeline 3 — see below)
```

---

## 5. Pipeline 2 — Copilot (Text Chat)

A persistent bidirectional gRPC stream. The Copilot pipeline handles text chat with full tool access.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  COPILOT PIPELINE  —  CopilotServicer (gRPC bidi streaming)                ║
╚══════════════════════════════════════════════════════════════════════════════╝

Client opens /ws/copilot
        │
        ▼
  Session init (in-memory, 30-min TTL):
  conversation_history, language, timezone,
  conversation_background, accumulated_words
        │
        │  [per message]
        ▼
  _handle_chat(request)
        │
        ├─ 1. retrieve_insights(user_id, query)
        │       vector similarity search → top-k relevant memories
        │       (3072-dim pgvector cosine similarity)
        │
        ├─ 2. build system prompt
        │       conversation_background + memory context
        │       + MCP tool descriptions
        │
        ├─ 3. get_tools_for_request(user_id)
        │       ALL_TOOLS (12 built-in)
        │       + mcp.get_tools_for_user(user_id)   ← per-user filtered, 30s cache
        │
        │
        ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  COPILOT AGENT  [6]  (LangChain tool binding + streaming)        │
  │  gemini-flash-lite · temp 0.7                                    │
  │                                                                  │
  │  llm.bind_tools(tools).astream(messages)                         │
  │                                                                  │
  │  Pass 1 — First LLM call:                                        │
  │  ┌─────────────────────────────────────────────────────────┐     │
  │  │  stream chunks:                                          │     │
  │  │  ├─ text delta?    → yield TokenChunk to client          │     │
  │  │  └─ tool_call?     → stop streaming, collect call args   │     │
  │  └──────────────────────┬──────────────────────────────────┘     │
  │                         │ tool calls?                            │
  │                    yes  ▼                        no              │
  │  ┌──────────────────────────────────────┐        ▼              │
  │  │  Parallel tool execution             │   → FinalReply        │
  │  │  asyncio.gather(*tool_calls)         │                       │
  │  │                                      │                       │
  │  │  execute_tool(name, args):           │                       │
  │  │  ├─ built-in tool? → run directly    │                       │
  │  │  └─ MCP tool?      → mcp_manager     │                       │
  │  │                      .call_mcp_tool()│                       │
  │  │                      (30s timeout)   │                       │
  │  │                                      │                       │
  │  │  yield StatusUpdate(tool_name)       │                       │
  │  │  → client shows "Using [tool]..."    │                       │
  │  └──────────────────────┬───────────────┘                       │
  │                         │                                       │
  │  Pass 2 — Second LLM call (with tool results):                  │
  │  ┌──────────────────────────────────────┐                       │
  │  │  stream final answer tokens          │                       │
  │  │  → yield TokenChunk to client        │                       │
  │  └──────────────────────────────────────┘                       │
  └──────────────────────────────────────────────────────────────────┘
        │
        ├─ update conversation_history
        ├─ asyncio.create_task(track_usage(user_id))
        │
        └─ accumulated_words ≥ 24,000?
                │ yes
                ▼
          asyncio.create_task(_analyze_and_summarize())
                │
                ▼
          INSIGHTS AGENT  [7]
          analyze_conversation_chunk(messages, user_id)
          → extract user_tasks + user_memory
          → embed + store in user_insights (pgvector)

  On disconnect:
        └─ asyncio.create_task(analyze_conversation_chunk())
```

---

## 6. Pipeline 3 — Background & Cross-Session

These agents run asynchronously, outside of live sessions.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  BACKGROUND PIPELINE  —  HTTP endpoints + cron tasks                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TRIGGER: POST /api/wingman/background  (client uploads scenario)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Store record (status = "processing")
        │
        ├── attachments?
        │       │ yes
        │       ▼
        │   FILE SUMMARIZER  [8]
        │   gemini-pro · temp 0.3  (multimodal)
        │   System: FILE_SUMMARIZER_PROMPT
        │   Human:  instruction + file data URIs
        │            (images/PDFs as base64, ≤ 15 MB each, max 5)
        │       │
        │   extracted facts
        │   → wingman_background.file_summary
        │
        └── (always, after summarizer if files present)
                │
                ▼
          PERSONA GENERATOR  [9]
          gemini-pro · temp 0.7
          System: PERSONA_GENERATION_SYSTEM_PROMPT
          Human:  conversation_background + file_summary
                │
          persona guidance text
          → wingman_background.generated_persona
          status = "ready"
                │
          (session start: fetched and cached in MonitorSession)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TRIGGER: post end-summary  OR  daily cron 06:00 UTC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  run_dashboard_agent(user_id)
        │
        ├─ fetch user_memory  (from user_memory table)
        ├─ fetch session_recaps  (last 7 days, up to 20)
        │
        ▼
  ┌─────────────────────────────────────────────────────────────┐
  │  DASHBOARD AGENT  [10]  (LangGraph ReAct)                   │
  │  gemini-2.5-flash · temp 0.5 · max 1500 tokens             │
  │                                                             │
  │  System: DASHBOARD_AGENT_PROMPTS                            │
  │  Human:  current_time + user_memory + recent_recaps         │
  │                                                             │
  │  tools = [web_search]   (DuckDuckGo, always available)      │
  │                                                             │
  │  LangGraph ainvoke():                                       │
  │  agent reasons → web_search? → results → final answer      │
  │                                                             │
  │  Output format (one line per card):                         │
  │  [reminder] Take your 9am standup prep notes               │
  │  [social]   Follow up with Alex from yesterday's call      │
  │  [insight]  You mention sleep 3x per week — try 10pm       │
  │  [discover] Article: Deep Work strategies (from search)    │
  │  [tip]      Morning hydration boosts focus by 14%          │
  └─────────────────────────────────────────────────────────────┘
        │
  parse cards: _CARD_RE = r"\[(type)]\s*(.+)"  (max 6 cards)
        │
  upsert dashboard_cache (PostgreSQL, per user_id)
        │
  client fetches on next app open: GET /api/dashboard
```

---

## 7. LangGraph Orchestration

Two agents are orchestrated by LangGraph: **Assist** [3] and **Dashboard** [10]. Both use `langgraph.prebuilt.create_react_agent` to build a compiled state machine.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  LANGGRAPH  —  ReAct State Machine (shared by agents 3 and 10)              ║
╚══════════════════════════════════════════════════════════════════════════════╝

create_react_agent(
  model = <gemini-llm>,
  tools = <tool list>
)
  │
  └─► Compiles a LangGraph graph:

       ╔══════════════╗
       ║   __start__  ║
       ║              ║
       ║  [System]    ║
       ║  [History?]  ║
       ║  [Human]     ║
       ╚══════╤═══════╝
              │
       ╔══════▼════════════════════════════════════╗
       ║   agent  node                             ║ ◄──────────────────────┐
       ║                                           ║                        │
       ║  LLM reasons over messages + tool schemas ║                        │
       ║                                           ║                        │
       ║  Decision:                                ║                        │
       ║  ┌─────────────────┐  ┌────────────────┐ ║                        │
       ║  │  text reply     │  │  tool_calls[]  │ ║                        │
       ║  └────────┬────────┘  └───────┬────────┘ ║                        │
       ╚═══════════│═══════════════════│═══════════╝                        │
                  │                   │                                     │
            text only            tool calls                                 │
                  │                   │                                     │
                  ▼                   ▼                                     │
       ╔══════════════╗    ╔══════════════════════════════╗                 │
       ║   __end__    ║    ║   tools  node                ║                 │
       ╚══════════════╝    ║                              ║                 │
                           ║  execute each tool call:     ║                 │
                           ║  • web_search (DuckDuckGo)   ║                 │
                           ║  • mcp_tool_N (via MCPMgr)   ║                 │
                           ║  • built-in tools            ║                 │
                           ║                              ║                 │
                           ║  results → ToolMessage       ║                 │
                           ║  appended to state.messages  ║                 │
                           ╚══════════════╤═══════════════╝                 │
                                          │                                 │
                                          └─────────────────────────────────┘
                                                (loop; max recursion_limit=6
                                                 = up to 2 tool rounds)

─────────────────────────────────────────────────────────────────────────────
STREAMING  (agent 3 — Assist, real-time)
─────────────────────────────────────────────────────────────────────────────

  stream_agent_response(agent, system, user)
    │
    └─ agent.astream_events({"messages": [...]}, version="v2")
         │
         ├─ on_chat_model_stream  → yield ("token", text)
         │                          forwarded to client per-token
         │
         ├─ on_tool_start         → yield ("tool_status", {name, args})
         │                          client shows "Searching..."
         │
         ├─ on_tool_end           → logged only (result not forwarded)
         │
         ├─ on_chat_model_end     → fallback full-text capture
         │                          (pro models may not stream token-by-token)
         │
         └─ [stream ends]         → yield ("done", full_text)

  ⚠️  WHY astream_events AND NOT stream_mode="messages"
  stream_mode="messages" buffers the ENTIRE response before emitting when
  tools are bound — LangGraph bug #5249. astream_events reliably emits
  token-by-token regardless of tool presence.

─────────────────────────────────────────────────────────────────────────────
BATCH  (agent 10 — Dashboard, background)
─────────────────────────────────────────────────────────────────────────────

  agent.ainvoke({"messages": [...]}, config={"recursion_limit": 6})
    │
    └─ result["messages"][-1].content  → parse cards

─────────────────────────────────────────────────────────────────────────────
CREATION POLICY
─────────────────────────────────────────────────────────────────────────────

  Assist  [3]:  created per-request (stateless graph, user-specific tools)
  Dashboard[10]: created per-invocation (web_search always present)

  ⚠️  WHY NOT langgraph.agents.create_agent (the newer API)
  Open bugs as of March 2026:
  • #34613 — breaks stream_mode="messages" token streaming
  • #34234 — async/ainvoke coroutine errors
  • #34463 — Gemini 3 models fall back to wrong tool strategy
  Deprecation warning for create_react_agent is suppressed programmatically.
  Revisit when the above issues are resolved.
```

---

## 8. MCP Tool Ecosystem

The MCPManager is the extensibility layer — it lets new tools be added without any code changes.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  MCP TOOL ECOSYSTEM  —  MCPManager (singleton)                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

service/
├── servers.json              ← tool server definitions
├── mcp_servers/              ← server process scripts
└── mcp_manager.py            ← singleton manager

servers.json schema:
┌─────────────────────────────────────────────────────────┐
│  {                                                       │
│    "servers": [                                          │
│      {                                                   │
│        "name":    "gmail",                              │
│        "command": "python",                              │
│        "args":    ["mcp_servers/gmail_server.py"],      │
│        "env":     { "GMAIL_CREDS": "${GMAIL_CREDS}" }  │
│      },                                                  │
│      { "name": "filesystem", ... },                     │
│      { "name": "calendar", ... }                        │
│    ]                                                     │
│  }                                                       │
└─────────────────────────────────────────────────────────┘

startup (init_mcp_manager()):
        │
        ├─ for each server in servers.json:
        │       spawn child process  (asyncio subprocess)
        │       connect MCP session  (stdio transport)
        │       discover tools       (session.list_tools())
        │       wrap as LangChain    (StructuredTool from Pydantic)
        │       store in conn.langchain_tools
        │
        └─ register tool_to_server mapping  (fast lookup)

per-request (get_tools_for_user(user_id)):
        │
        ├─ check cache (30s TTL per user_id)
        │
        └─ query mcp_server_config table
             (user-level enable/disable per server)
             filter conn.langchain_tools by enabled servers
             cache result → return filtered list

─────────────────────────────────────────────────────────────────────────────
TOOL WRAPPING: MCP Tool → LangChain StructuredTool
─────────────────────────────────────────────────────────────────────────────

  MCP tool JSON schema:
  { "name": "read_file",
    "description": "Read a file from the filesystem",
    "inputSchema": {
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "encoding": { "type": "string" }
      },
      "required": ["path"]
    }
  }
        │
        ▼
  _build_pydantic_model("read_file_Input", inputSchema)
        │
  dynamically creates:
  class read_file_Input(BaseModel):
      path: str
      encoding: Optional[str] = None
        │
        ▼
  StructuredTool(
    name        = "read_file",
    description = "Read a file from the filesystem",
    args_schema = read_file_Input,
    coroutine   = async def run(**kwargs):
                    return await call_mcp_tool("read_file", kwargs)
  )

─────────────────────────────────────────────────────────────────────────────
BUILT-IN TOOLS  (always available, tools.py)
─────────────────────────────────────────────────────────────────────────────

  ┌────────────────────┬──────────────────────────────────────────────────┐
  │  Tool              │  Backend                                         │
  ├────────────────────┼──────────────────────────────────────────────────┤
  │  get_weather       │  WeatherAPI.com (async HTTP)                     │
  │  get_current_time  │  stdlib ZoneInfo (timezone-aware)                │
  │  web_search        │  DuckDuckGo DDGS (3 results)                     │
  │  search_news       │  DuckDuckGo news (with dates + sources)          │
  │  get_stock_price   │  Yahoo Finance (yfinance)                        │
  │  wikipedia_search  │  Wikipedia API (disambiguation handled)           │
  │  summarize_url     │  httpx fetch + get_llm("url_summarizer")         │
  │  set_reminder      │  INSERT into reminders table                     │
  │  daily_briefing    │  weather + news + stocks aggregated              │
  └────────────────────┴──────────────────────────────────────────────────┘

─────────────────────────────────────────────────────────────────────────────
ERROR HANDLING
─────────────────────────────────────────────────────────────────────────────

  startup failure   → logged, server skipped, system degrades gracefully
  mid-session crash → conn.healthy = False
                      tool call returns error string to LLM
                      asyncio.create_task(_reconnect_server()) background
  timeout (30s)     → error string returned to LLM
  name collision    → warning logged, later server wins
```

---

## 9. ConversationRecord — Shared Memory Bus

`ConversationRecord` is the per-session event log. Every agent reads a different view of the same data.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  ConversationRecord  —  per-session event log                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

Entry types stored in order:

  ┌────────────────────────────────────────────────────────────────────────┐
  │ entry_type     speaker    content                         agent        │
  │ ─────────────────────────────────────────────────────────────────────  │
  │ "compact"      SYSTEM     [summary of earlier convo]      null         │ ← written by compactor
  │ "transcript"   USER       "So the Q3 numbers are..."      null         │
  │ "transcript"   OTHER      "Right, about 4.2 billion."     null         │
  │ "user_query"   USER       "What should I say here?"       null         │
  │ "agent_resp"   AI         "That figure is outdated..."    "passive"    │
  │ "transcript"   USER       "And about the margin?"         null         │
  │ "agent_resp"   AI         "Correct stat: 3.8B in 2025"   "assist"     │
  │ "transcript"   OTHER      "I'll look into it."            null         │
  │ "agent_resp"   AI         null  ← streaming placeholder  "passive"    │
  └────────────────────────────────────────────────────────────────────────┘

Context builder views (each agent calls one method):

  Method                    What it includes                    Agents
  ──────────────────────────────────────────────────────────────────────
  get_transcript()          compact + transcript only           [7] insights
  get_passive_context()     compact + transcript                [1] passive
                            + user_query + passive AI
  get_proactive_context()   compact + transcript                [2] gate
                            + user_query + assist AI            [3] assist
                            + metadata
  get_compact_input()       compact + transcript                [4] compactor
                            + user_query + ALL AI responses     [5] end_summary

Compaction threshold: 24,000 words (~32k tokens)
  needs_compaction() == True
        │
        ▼
  compact()  calls COMPACTOR AGENT [4]
  all entries → 1 CompactEntry  (verbatim recent turns kept)
```

---

## 10. Persistence & Data Model

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PostgreSQL  +  pgvector                                                    ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌────────────────────┬──────────────────────────────┬──────────────────────────┐
│  Table             │  Written by                  │  Read by                 │
├────────────────────┼──────────────────────────────┼──────────────────────────┤
│  users             │  /internal/ensure-user        │  session init            │
│  user_memory       │  end_summary [5]              │  dashboard [10],         │
│                    │                              │  end_summary input       │
│  user_insights     │  insights [7]  (pgvector)    │  copilot retrieval,      │
│  (3072-dim embed)  │                              │  wingman RAG             │
│  session_recaps    │  end_summary [5]              │  dashboard [10],         │
│                    │                              │  GET /wingman/recaps     │
│  dashboard_cache   │  dashboard [10]               │  GET /api/dashboard      │
│  wingman_background│  HTTP background endpoints   │  session init,           │
│  + generated_      │  + persona_gen [9]           │  passive [1]             │
│    persona         │  + file_summarizer [8]       │                          │
│  reminders         │  set_reminder tool           │  check_reminders() cron  │
│  push_tokens       │  POST /push/register         │  APNs / Expo push        │
│  mcp_server_config │  POST /api/mcp/config        │  MCPManager per-user     │
│  tts_config        │  POST /api/tts/config        │  TTS synthesize endpoint │
│  usage_tracking    │  track_usage() per request   │  admin analytics         │
│  briefing_config   │  POST /briefing/config       │  daily_briefing tool     │
│  insight_settings  │  POST /settings/insights     │  scheduler, insights [7] │
└────────────────────┴──────────────────────────────┴──────────────────────────┘

Vector memory flow:

  conversation text
        │
        ▼
  INSIGHTS AGENT [7]
  (extract facts, tasks, memories)
        │
        ▼
  get_embeddings().embed_query(text)     ← gemini-embedding-001, 3072-dim
        │
        ▼
  INSERT INTO user_insights
  (user_id, embedding, insight_text, insight_type, priority, expires_at)
        │
  ─────────────────────────────────────────
  later: retrieve_insights(user_id, query)
  ─────────────────────────────────────────
        │
  embed query → cosine similarity search
  (sequential scan — 3072 dims > pgvector index limit of 2000)
        │
  top-k results → injected into copilot system prompt
```

---

## 11. Scheduler & Push System

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  SCHEDULERS  —  background cron tasks                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

  ┌──────────────────────────────────────────────────────────────────────────┐
  │  check_reminders()           every 30s                                   │
  │                                                                          │
  │  SELECT * FROM reminders WHERE fire_at <= NOW() AND fired = FALSE        │
  │  → dispatch_push_notification() per due reminder                         │
  │  → UPDATE reminders SET fired = TRUE                                     │
  └──────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────┐
  │  process_insights_scheduler()   every 300s                               │
  │                                                                          │
  │  get_pending_insights() — notified = FALSE, priority ≥ threshold         │
  │  ├─ high priority (≥ 4), recent (< 5min) → send_realtime_insights()     │
  │  └─ daily briefing (08:00 user local time) → send_daily_briefing()      │
  │                                                                          │
  │  cleanup_old_insights() — DELETE WHERE expires_at < NOW()               │
  └──────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────┐
  │  dashboard_refresh_scheduler()  daily 06:00 UTC                          │
  │                                                                          │
  │  SELECT DISTINCT user_id FROM usage_tracking WHERE date = TODAY          │
  │  → asyncio.create_task(run_dashboard_agent(user_id))  per active user   │
  └──────────────────────────────────────────────────────────────────────────┘

Push notification routing:

  dispatch_push_notification(user_id, title, body, data)
        │
        ├─ fetch push_token from DB
        │
        ├─ platform = "apns"?  → send_apns_notification()
        │                          aioapns client (lazy-init)
        │                          APNS_KEY_PATH / KEY_ID / TEAM_ID
        │
        └─ platform = "expo"?  → send_push_notification()
                                  Expo HTTP API
                                  https://exp.host/--/api/v2/push/send

  send_silent_push(user_id, event, data)
        │
        └─ content-available push (no alert)
           wakes iOS client in background
           used by: end_summary [5] → notify recap ready
```

---

## 12. LLM Provider Layer

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  LLM PROVIDER SYSTEM  —  llm_provider.py + providers.json                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

  All model assignments live in providers.json.
  Switch any agent's model with a config edit + restart — no code change.

  get_llm("role") → LangChain BaseChatModel

  Role → model mapping (defaults):

  ┌────────────────────────┬──────────────────────────────┬────────┬──────────┐
  │  Role                  │  Default model               │  Temp  │  Tokens  │
  ├────────────────────────┼──────────────────────────────┼────────┼──────────┤
  │  wingman_passive   [1] │  gemini-flash-lite-latest    │  0.7   │  default │
  │  wingman_gate      [2] │  gemini-flash-lite-latest    │  0.5   │  150     │
  │  wingman_assist    [3] │  gemini-3-pro-preview        │  0.9   │  600     │
  │  wingman_summarizer[4] │  gemini-flash-lite-latest    │  0.2   │  3000    │
  │  wingman_end_summ  [5] │  gemini-flash-lite-latest    │  0.3   │  2000    │
  │  copilot_chat      [6] │  gemini-flash-lite-latest    │  0.7   │  default │
  │  insights          [7] │  gemini-2.0-flash-lite       │  0.3   │  struct. │
  │  url_summarizer        │  gemini-2.5-flash            │  0.3   │  default │
  │  dashboard        [10] │  gemini-2.5-flash            │  0.5   │  1500    │
  └────────────────────────┴──────────────────────────────┴────────┴──────────┘

  Supported providers (no code change for OpenAI-compatible):

  google  ·  anthropic  ·  deepseek  ·  moonshot  ·  qwen
  glm     ·  minimax    ·  grok      ·  openai_compatible

  Example: switch assist to Claude for a session:
  "wingman_assist": {
    "provider": "anthropic",
    "model":    "claude-sonnet-4-6",
    "temperature": 0.9,
    "max_tokens": 600
  }

  Embeddings (separate config):
  gemini-embedding-001  →  3072 dimensions  →  pgvector user_insights table
  ⚠️ Switching embedding providers requires full re-embedding of all stored vectors.
```

---

## 13. End-to-End Request Trace

One utterance that triggers a proactive assist with web search — the most complex path.

```
t=0ms    User says: "Actually, I read the figure was 5 billion."
         ───────────────────────────────────────────────────────

t=0ms    Apple SpeechAnalyzer (on-device Neural Engine)
         → continuous transcript buffer
         → VAD detects silence: "OTHER: Actually, I read the figure was 5 billion."

t=~50ms  iOS sends WebSocket message:
         { type: "proactive",
           transcript: [{speaker:"OTHER", content:"Actually, I read..."}],
           metadata: {silence_secs: 1.2, context: "financial discussion"} }

t=~60ms  Go Gateway :5000
         Auth ✓  (Firebase JWT → X-Verified-User-ID)
         Rate-limit ✓  (40 req/60s per user, not exceeded)
         WebSocket proxied → gRPC stream → Python :5001

t=~70ms  WingmanServicer._handle_proactive()
         record.append_transcript("OTHER", "Actually, I read...")
         Anti-spam: 35 chars ✓  cooldown 90s ✓  assists=2/10 ✓

t=~80ms  GATE AGENT [2] invoked
         gemini-flash-lite · temp 0.5 · max 150 tokens
         Input: compact_prefix + transcript + metadata
         ↳ model sees factual dispute in real-time conversation

t=~380ms GATE returns: {"trigger": true, "user_nudge": "Let me think about that."}

t=~390ms user_nudge pushed immediately → gRPC → gateway → iOS TTS
         User hears: "Let me think about that."  ← buys 1-3s while assist thinks

t=~400ms ASSIST AGENT [3] starts (LangGraph ReAct)
         gemini-pro · temp 0.9 · max 600 tokens
         tools = mcp.get_tools_for_user(user_id)  ← ["web_search", "gmail", ...]

         LangGraph state machine:
         agent node: "I need to verify this figure — call web_search"

t=~410ms on_tool_start event:
         yield ("tool_status", {"name": "web_search", "args": {"query": "..."}})
         → gRPC WingmanResponse { status: StatusUpdate { tool_name: "web_search" } }
         → iOS shows "Searching..." indicator

t=~1800ms web_search returns top 3 DuckDuckGo results

t=~1810ms LangGraph tools node: results appended to messages
          agent node again: model reads results, decides: "enough to answer"

t=~1820ms on_chat_model_stream events begin:
          yield ("token", "Actually, the ")
          yield ("token", "correct figure is ")
          yield ("token", "approximately 3.8 billion ")
          yield ("token", "based on the 2025 annual report. ")
          yield ("token", "You may want to gently clarify.")

          Each token: gRPC WingmanResponse { token: TokenChunk }
          → gateway → iOS AVSpeechSynthesizer speaks each chunk as it arrives

t=~2800ms yield ("done", full_text)
          WingmanResponse { done: DoneSignal() }

t=~2810ms record.fill_placeholder("assist", full_text)
          session.last_assist_push = now()  ← reset cooldown

t=~2815ms compact check: word_count = 1,240 → no compaction needed

─────────────────────────────────────────────────────────────────────
  Latency summary:
  Gate decision          :  ~300ms
  Nudge delivered        :  ~390ms  ← user covered from here
  Web search             :  ~1400ms
  Assist first token     :  ~1820ms (TTFB from gate trigger)
  Full response streamed :  ~2800ms
─────────────────────────────────────────────────────────────────────

t=disconnect  WingmanDisconnect()
  asyncio.create_task(analyze_conversation_chunk())   → INSIGHTS [7]
  asyncio.create_task(_run_end_summary())             → END-SUMMARY [5]
    └─ asyncio.create_task(run_dashboard_agent())     → DASHBOARD [10]
```

---

## 14. Design Decisions & Trade-offs

```
┌──────────────────────────────┬─────────────────────────────────┬──────────────────────────────┐
│  Decision                    │  Rationale                      │  Trade-off                   │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  On-device STT/TTS           │  $0 cost; works offline;         │  Lower accuracy than cloud;  │
│  (Apple Neural Engine)       │  privacy (audio never leaves     │  no real-time adaptation     │
│                              │  device)                        │                              │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  Gate model before assist    │  Prevents expensive pro-model    │  ~300ms added latency on     │
│  (flash-lite as gatekeeper)  │  calls; self-throttles based     │  every proactive check;      │
│                              │  on context + metadata           │  gate can miss edge cases    │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  Nudge delivered immediately │  User not left in silence while  │  Nudge must be generic       │
│  (before assist completes)   │  pro model thinks (1-3s)         │  enough to not conflict      │
│                              │                                 │  with assist output          │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  astream_events over         │  Only reliable token-by-token    │  More complex event          │
│  stream_mode="messages"      │  streaming with tools bound      │  filtering code; must        │
│                              │  (LangGraph bug #5249)           │  ignore internal events      │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  create_react_agent over     │  Newer API has open bugs         │  Deprecation warning;        │
│  create_agent (newer API)    │  (#34613, #34234, #34463)        │  must suppress; revisit      │
│                              │  affecting Gemini + streaming     │  when fixed                 │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  Per-user MCP tool filtering │  Users only see tools they've    │  30s cache can serve         │
│  with 30s cache              │  enabled; reduces noise in        │  stale config briefly        │
│                              │  LLM context                     │                              │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  ConversationRecord          │  Single source of truth for all  │  In-memory; lost on crash    │
│  (in-memory, per session)    │  agents; no DB round-trips        │  (acceptable: sessions are   │
│                              │  during live conversation         │  short-lived)                │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  Compaction at 24k words     │  Keeps context within model       │  Compactor runs synchronous- │
│  (not per turn)              │  limits without per-turn cost;    │  ly in session — small       │
│                              │  preserves recent turns verbatim  │  latency spike at threshold  │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  Sequential scan for         │  3072 dims exceeds pgvector       │  Slower retrieval at scale;  │
│  pgvector similarity         │  2000-dim HNSW index limit        │  acceptable at current       │
│                              │                                   │  user volume                 │
├──────────────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│  providers.json for LLM      │  Swap any agent's model without   │  Embedding provider locked   │
│  role mapping                │  code change; mix providers        │  (changing requires full     │
│                              │  per role                         │  re-embedding of all vectors)│
└──────────────────────────────┴─────────────────────────────────┴──────────────────────────────┘
```
