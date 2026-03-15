# Wingman — Architecture & Agent Diagrams

## Contents

1. [System Overview](#1-system-overview)
2. [Per-Session Agent Pipeline](#2-per-session-agent-pipeline)
3. [LangGraph: ReAct Assist Agent](#3-langgraph-react-assist-agent)
4. [LangGraph: Dashboard Agent](#4-langgraph-dashboard-agent)
5. [ConversationRecord — Context Routing](#5-conversationrecord--context-routing)
6. [Background Agent Pipeline](#6-background-agent-pipeline)
7. [Memory & Persistence](#7-memory--persistence)
8. [Full Data Flow (Single Utterance)](#8-full-data-flow-single-utterance)

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            iOS Client                                        │
│  Apple SpeechAnalyzer ──► VAD ──► text utterances                           │
│  AVSpeechSynthesizer  ◄── TTS ◄── streamed tokens                           │
└────────────────────────────┬────────────────────────────────────────────────┘
                             │  WebSocket JSON  ·  Bearer / Firebase JWT
                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Go Gateway  :5000                                     │
│  ┌──────────┐  ┌────────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │  Auth    │  │  Rate Limiting │  │  WS Upgrade   │  │  HTTP Proxy      │ │
│  │ Firebase │  │ per-user slide │  │  /ws/wingman  │  │  /api/*          │ │
│  │ JWT / key│  │ window in-mem  │  │  /ws/stt      │  │  /ws/copilot     │ │
│  └──────────┘  └────────────────┘  └───────┬───────┘  └────────┬─────────┘ │
└──────────────────────────────────────────── │ ─────────────────│───────────┘
                                              │ gRPC              │ HTTP
                             ┌────────────────┘                   │
                             ▼                                     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                     Python Service  :5001  (FastAPI + gRPC)                 │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  WingmanServicer  (gRPC)                                             │  │
│  │                                                                       │  │
│  │  ┌─────────────┐   ┌──────────────┐   ┌──────────────────────────┐  │  │
│  │  │  Passive    │   │  Gate        │   │  Assist                  │  │  │
│  │  │  Agent      │   │  Agent       │   │  Agent                   │  │  │
│  │  │  (stream)   │   │  (JSON dec.) │──►│  LangGraph ReAct         │  │  │
│  │  └─────────────┘   └──────────────┘   │  + MCP tools             │  │  │
│  │                                        └──────────────────────────┘  │  │
│  │  ┌─────────────┐   ┌──────────────┐                                  │  │
│  │  │  Compactor  │   │  End Summary │──► dashboard_agent (async task)  │  │
│  │  │  Agent      │   │  Agent       │──► insights (async task)         │  │
│  │  └─────────────┘   └──────────────┘                                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  HTTP Endpoints  (background mgmt, user mgmt, dashboard, TTS, etc.)  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐     ┌──────────────────┐
                    │   PostgreSQL    │     │  Gemini API       │
                    │  (pgvector)     │     │  (all LLM calls)  │
                    │                 │     │                   │
                    │  users          │     │  flash-lite  ──── passive
                    │  user_memory    │     │  flash-lite  ──── gate
                    │  user_insights  │     │  pro         ──── assist
                    │  session_recaps │     │  flash-lite  ──── compactor
                    │  dashboard_cache│     │  flash-lite  ──── end_summary
                    │  wingman_bg     │     │  pro         ──── file_sum
                    └─────────────────┘     │  pro         ──── persona_gen
                                            │  2.5-flash   ──── dashboard
                                            └──────────────────┘
```

---

## 2. Per-Session Agent Pipeline

Every message from the client enters the `Wingman` gRPC handler. The `request.type` field determines which sub-pipeline runs.

```
WebSocket utterance arrives
         │
         ▼
  ┌─────────────┐
  │  Wingman()  │  gRPC dispatcher
  └──────┬──────┘
         │
   type? │
   ┌─────┴──────┐
   │            │
passive      proactive
   │            │
   ▼            ▼
┌──────────┐  ┌───────────────────────────────────────────────────────────┐
│ PASSIVE  │  │  PROACTIVE PIPELINE                                        │
│ PIPELINE │  │                                                            │
│          │  │  Anti-spam checks ──────────────────────────────► skip    │
│  get_    │  │   • MIN_NEW_CHARS (20)                                     │
│  passive │  │   • cooldown (60s between assists)                         │
│  messages│  │   • session_mode check                                     │
│    │     │  │          │ passes                                          │
│    ▼     │  │          ▼                                                 │
│  LLM     │  │  ┌────────────────┐                                        │
│  stream  │  │  │  GATE AGENT    │  gemini-flash-lite · temp 0.5          │
│    │     │  │  │                │  max 150 tokens                        │
│    ▼     │  │  │  get_gate_     │                                        │
│  stream  │  │  │  messages()    │                                        │
│  tokens  │  │  │  • compact pfx │                                        │
│  to      │  │  │  • transcript  │                                        │
│  client  │  │  │  • assist hist │                                        │
│          │  │  │  • metadata    │                                        │
│  ──────► │  │  │    (silence,   │                                        │
│  after:  │  │  │    last assist)│                                        │
│  compact │  │  └───────┬────────┘                                        │
│  check   │  │          │                                                 │
└──────────┘  │   JSON: {trigger, user_nudge}                              │
              │          │                                                 │
              │   trigger=false ──────────────────────────────────► done  │
              │          │ trigger=true                                    │
              │          ▼                                                 │
              │  push nudge to client immediately                          │
              │  (user_nudge → speak_as_user TTS)                         │
              │          │                                                 │
              │          ▼                                                 │
              │  ┌──────────────────────────────────────────────────┐     │
              │  │  ASSIST AGENT  (LangGraph ReAct)                 │     │
              │  │                                                   │     │
              │  │  gemini-pro · temp 0.9 · max 600 tokens          │     │
              │  │                                                   │     │
              │  │  tools = mcp.get_tools_for_user(user_id)         │     │
              │  │  agent = create_react_search_agent(llm, tools)   │     │
              │  │  ──────────────────────────────────────────────  │     │
              │  │  stream_agent_response()                          │     │
              │  │   astream_events(version="v2")                   │     │
              │  │   ├─ on_chat_model_stream → ("token", text)      │     │
              │  │   ├─ on_tool_start        → ("tool_status", ...) │     │
              │  │   └─ done                 → ("done", full_text)  │     │
              │  └──────────────────────────────────────────────────┘     │
              │          │                                                 │
              │          ▼                                                 │
              │  stream tokens → gRPC → Go gateway → client TTS           │
              │          │                                                 │
              │  after: compact check (word count ≥ 24,000?)              │
              │          │ yes → compactor agent (async)                  │
              └───────────────────────────────────────────────────────────┘

WebSocket disconnect
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  WingmanDisconnect()                                        │
│                                                             │
│  asyncio.create_task(analyze_conversation_chunk(...))       │
│    └─ insights agent: extract user_insights (pgvector)     │
│                                                             │
│  asyncio.create_task(_run_end_summary(...))                 │
│    └─ end_summary agent → title + recap + user_memory      │
│         └─ asyncio.create_task(run_dashboard_agent(...))   │
│               └─ dashboard agent: refresh home screen      │
└────────────────────────────────────────────────────────────┘
```

---

## 3. LangGraph: ReAct Assist Agent

The `wingman_assist` and `dashboard` agents both run inside a LangGraph `create_react_agent` graph. This is the internal state machine LangGraph compiles and runs for each activation.

```
create_react_agent(llm=gemini-pro, tools=mcp_tools)
                    │
         ┌──────────▼──────────────────────────────┐
         │         LangGraph State Machine          │
         │                                          │
         │    State: { messages: [...] }            │
         └──────────────────┬──────────────────────┘
                            │
              ┌─────────────▼─────────────┐
              │         __start__          │
              │  [SystemMessage]           │
              │  [ChatHistory (optional)]  │
              │  [HumanMessage]            │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │       agent  (LLM)         │◄──────────────────┐
              │                            │                   │
              │  gemini-pro reasons:       │                   │
              │  • should I call a tool?   │                   │
              │  • which tool + what args? │                   │
              └──────────┬────────────────┘                   │
                         │                                     │
           ┌─────────────┴──────────────┐                     │
           │                            │                     │
     text reply                  tool_calls: [...]            │
           │                            │                     │
           ▼                            ▼                     │
   ┌──────────────┐           ┌──────────────────┐           │
   │   __end__    │           │    tools node     │           │
   │              │           │                  │           │
   │ yield tokens │           │  execute each    │           │
   │ via astream_ │           │  tool call:      │           │
   │ events       │           │  • web_search    │           │
   └──────────────┘           │  • mcp_tool_N    │           │
                              └────────┬─────────┘           │
                                       │                     │
                              tool results appended          │
                              to messages state              │
                                       │                     │
                                       └─────────────────────┘
                                        (loop back to agent)
                                        max recursion_limit=6
                                        (≤ 2 tool rounds)

─────────────────────────────────────────────────────────────────
Event stream (astream_events version="v2") visible to caller:

  on_chat_model_stream  → ("token", text)          streamed per token
  on_tool_start         → ("tool_status", {name, args})  before exec
  on_tool_end           → logged only (result logged, not forwarded)
  on_chat_model_end     → fallback full-text capture (pro models)
  [stream ends]         → ("done", full_text)

─────────────────────────────────────────────────────────────────
Why astream_events and not stream_mode="messages":

  stream_mode="messages" has a confirmed LangGraph bug (#5249):
  when tools are bound, it buffers the ENTIRE response and emits
  it all at once — useless for live conversation streaming.

  astream_events emits token-by-token regardless of tool presence.
```

---

## 4. LangGraph: Dashboard Agent

The dashboard agent runs the same LangGraph graph but with a fixed tool (`web_search`) and calls `ainvoke` (not streaming) since it runs in the background.

```
run_dashboard_agent(user_id)
         │
         ▼
  Fetch from PostgreSQL
  ├─ user_memory  (user_memory table)
  └─ session_recaps  (last 7 days)
         │
         ▼
  Build prompt
  ├─ system: DASHBOARD_AGENT_PROMPTS
  └─ human:  current_time + user_memory + recaps
         │
         ▼
  create_react_search_agent(
    llm   = gemini-2.5-flash,
    tools = [web_search]          ← always present
  )
         │
         ▼
  ┌───────────────────────────────────────────┐
  │         LangGraph ReAct  (ainvoke)        │
  │                                           │
  │  agent ──► should I web_search?           │
  │              │ yes          │ no           │
  │              ▼              ▼             │
  │          web_search    direct answer      │
  │          (DuckDuckGo)       │             │
  │              │              │             │
  │          results ──► agent reasons again  │
  │                           │              │
  │                     final answer         │
  └───────────────────────────┬───────────────┘
                              │
                    Parse output lines:
                    "[type] content" per card
                              │
                    ┌─────────▼──────────┐
                    │  _parse_cards()    │
                    │  max 6 cards       │
                    │  types:            │
                    │  • reminder        │
                    │  • social          │
                    │  • insight         │
                    │  • discover        │
                    │  • tip             │
                    └─────────┬──────────┘
                              │
                    Upsert dashboard_cache
                    (PostgreSQL, per user_id)
                              │
                    Client fetches on next open
```

---

## 5. ConversationRecord — Context Routing

`ConversationRecord` is the session's single source of truth. It is a chronological log of every event. Agents each call a different view method to get only the context they need.

```
ConversationRecord.entries  (ordered list)
┌─────────────────────────────────────────────────────────────────┐
│  entry_type   speaker    content                    agent       │
│  ─────────────────────────────────────────────────────────────  │
│  "compact"    SYSTEM     [summary of older convo]   null        │  ← replaces all prior entries after compaction
│  "transcript" USER       "So the Q3 numbers are..." null        │
│  "transcript" OTHER      "Right, 4.2 billion..."   null        │
│  "user_query" USER       "What should I say?"      null        │
│  "agent_resp" AI         "Actually that figure..." passive      │
│  "transcript" USER       "Thanks. And about the..."null        │
│  "agent_resp" AI         "The correct stat is..."  assist       │
│  "transcript" OTHER      "I agree with that."      null        │
│  "agent_resp" AI         null  ← placeholder (streaming)  passive │
└─────────────────────────────────────────────────────────────────┘

Context builder views:

  get_transcript()         ─── compact + transcript only
                               │
                               └─► insights agent (analyze_conversation_chunk)

  get_passive_context()    ─── compact + transcript + user_query + passive responses
                               │
                               └─► wingman_passive

  get_proactive_context()  ─── compact + transcript + user_query + assist responses + metadata
                               │
                               ├─► wingman_gate
                               └─► wingman_assist

  get_compact_input()      ─── compact + transcript + user_query + ALL agent responses
                               │
                               ├─► wingman_compactor
                               └─► wingman_end_summary

─────────────────────────────────────────────────────────────────
Compaction trigger:

  after every passive or assist response:
    if record.needs_compaction():        ← word count ≥ 24,000
        await record.compact()
              │
              ▼
        wingman_compactor LLM call
        all entries → 1 "compact" entry
        (verbatim recent turns preserved)
```

---

## 6. Background Agent Pipeline

These agents run asynchronously when a Wingman Background is created or updated via HTTP. They are not part of the real-time session.

```
POST /api/wingman/background  (client uploads background + optional files)
         │
         ▼
  Store in wingman_background table  (status = "processing")
         │
         ├─── files attached? ──────────────────────────────────────────┐
         │                                                               │
         │    no files                                                   │ yes
         │       │                                              ┌────────▼────────┐
         │       │                                              │ FILE SUMMARIZER │
         │       │                                              │                 │
         │       │                                              │ gemini-pro      │
         │       │                                              │ temp 0.3        │
         │       │                                              │                 │
         │       │                                              │ multimodal:     │
         │       │                                              │ text + file     │
         │       │                                              │ data URIs       │
         │       │                                              │ (images/PDFs)   │
         │       │                                              └────────┬────────┘
         │       │                                                       │
         │       │                                              extracted facts
         │       │                                              → wingman_bg.
         │       │                                                file_summary
         │       │                                                       │
         └───────┴───────────────────────────────────────────────────── ┤
                                                                        │
                                                              ┌─────────▼─────────┐
                                                              │  PERSONA GENERATOR │
                                                              │                    │
                                                              │  gemini-pro        │
                                                              │  temp 0.7          │
                                                              │                    │
                                                              │  input:            │
                                                              │  • conversation_   │
                                                              │    background      │
                                                              │  • file_summary    │
                                                              │    (if available)  │
                                                              └─────────┬──────────┘
                                                                        │
                                                              generated persona text
                                                              → wingman_bg.
                                                                generated_persona
                                                                        │
                                                              status = "ready"
                                                                        │
                                                                        ▼
                                                              Next session start:
                                                              _sync_session_config()
                                                              fetches persona + file_summary
                                                              into MonitorSession cache
                                                                        │
                                                                        ▼
                                                              Injected into passive agent
                                                              system prompt per utterance
```

---

## 7. Memory & Persistence

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        PostgreSQL  (+ pgvector)                           │
│                                                                            │
│  users                                                                     │
│  ├─ user_id, name, phone, created_at                                      │
│  └─ fetched once at session start → cached in MonitorSession.user_name    │
│                                                                            │
│  user_memory                                                               │
│  ├─ user_id, memory_text (freeform XML-structured)                        │
│  ├─ written by: wingman_end_summary agent (on disconnect)                 │
│  └─ read by:   dashboard agent (for card generation)                      │
│                                                                            │
│  user_insights                                        ← pgvector          │
│  ├─ user_id, embedding (3072-dim), insight_text                           │
│  ├─ written by: insights agent (async on disconnect)                      │
│  └─ read by:   RAG retrieval (similarity search)                          │
│                                                                            │
│  session_recaps                                                            │
│  ├─ session_id, user_id, title, recap, created_at                        │
│  ├─ written by: wingman_end_summary agent                                 │
│  └─ read by:   dashboard agent (last 7 days)                              │
│                                                                            │
│  dashboard_cache                                                           │
│  ├─ user_id, cards (JSONB), generated_at                                  │
│  ├─ written by: dashboard agent (upsert)                                  │
│  └─ read by:   client GET /api/dashboard                                  │
│                                                                            │
│  wingman_background                                                        │
│  ├─ id, user_id, conversation_background, generated_persona,              │
│  │  file_summary, status                                                   │
│  ├─ written by: background HTTP endpoint + persona/file agents            │
│  └─ read by:   _sync_session_config() at session start                    │
└──────────────────────────────────────────────────────────────────────────┘

Memory write timeline (single conversation):

  session start ──────────────────────────────────────── session end
       │                                                      │
       │  [live session: nothing written to DB]               │
       │                                                      │
       └──────────────────────────────────────────────────── disconnect
                                                              │
                                               ┌─────────────┴──────────────┐
                                               │                            │
                                    asyncio.create_task              asyncio.create_task
                                               │                            │
                                    ┌──────────▼──────────┐   ┌────────────▼──────────┐
                                    │  analyze_chunk()    │   │  _run_end_summary()   │
                                    │  insights agent     │   │  end summary agent    │
                                    │        │            │   │        │              │
                                    │  → user_insights    │   │  → session_recaps     │
                                    │    (pgvector)       │   │  → user_memory        │
                                    └─────────────────────┘   │        │              │
                                                              │  → run_dashboard_     │
                                                              │    agent() (task)     │
                                                              │        │              │
                                                              │  → dashboard_cache    │
                                                              └───────────────────────┘
```

---

## 8. Full Data Flow (Single Utterance)

End-to-end trace of one user utterance that triggers a proactive assist with web search.

```
User speaks
    │
    │ [on-device]
    ▼
Apple SpeechAnalyzer  (Neural Engine STT, no network)
    │
VAD silence detected
    │
    ▼
iOS sends WS message:
  { type: "proactive", transcript: [...], user_query: "...", metadata: {...} }
    │
    │ WebSocket · Bearer token
    ▼
Go Gateway :5000
  Auth ✓  Rate-limit ✓  Upgrade WS
    │
    │ gRPC streaming
    ▼
WingmanServicer.Wingman()
    │
    ├─ _sync_session_config()   ← fetch persona from DB if not cached
    │
    ├─ record.append_transcript(...)
    │
    ▼
_handle_proactive()
    │
    ├─ anti-spam check  →  pass
    │
    ├─ [PARALLEL, fire-and-forget]
    │   gate_messages = session.get_gate_messages(metadata)
    │       compact_prefix + transcript + assist_history + metadata
    │
    ▼
GATE AGENT  (gemini-flash-lite, temp 0.5, max 150 tokens)
    │
    ▼
JSON: { "trigger": true, "user_nudge": "That's an interesting point..." }
    │
    ├─ push nudge → gRPC → gateway → client  [immediate TTS to user]
    │
    ▼
ASSIST AGENT  (LangGraph ReAct)
    │
    │  mcp_tools = mcp.get_tools_for_user(user_id)
    │  agent = create_react_search_agent(gemini-pro, mcp_tools)
    │
    │  stream_agent_response(agent, system_prompt, user_prompt)
    │    astream_events(version="v2")
    │
    ▼
LangGraph state machine starts:
    │
    ├─ agent node (gemini-pro reasons about transcript)
    │     └─► decides: need to verify a statistic → call web_search
    │
    │  [astream_events emits "on_tool_start"]
    │  yield ("tool_status", {"name": "web_search", "args": {...}})
    │      │
    │      ▼
    │  gRPC → gateway:
    │    WingmanResponse { status: StatusUpdate { tool_name: "web_search" } }
    │      │
    │      ▼
    │  iOS shows "Searching..." indicator
    │
    ├─ tools node (web_search executes, Tavily returns results)
    │
    ├─ agent node again (reasons with search results, produces final answer)
    │
    │  [astream_events emits "on_chat_model_stream" per token]
    │  yield ("token", "The correct figure is approximately...")
    │      │
    │      ▼
    │  gRPC → gateway:
    │    WingmanResponse { token: TokenChunk { text: "The correct..." } }
    │      │
    │      ▼
    │  iOS AVSpeechSynthesizer speaks each chunk as it arrives
    │
    └─ ("done", full_text)
          │
          ▼
    WingmanResponse { done: DoneSignal() }
          │
    record.fill_agent_placeholder("assist", full_text)
          │
    record.needs_compaction()?
      │ yes → await record.compact()  [wingman_compactor LLM call]
      │ no  → continue
          │
    session.last_assist_push = time.now()  [reset cooldown]

──────────────────────────────────────────────────────────────
Total latency budget (typical):

  STT (on-device)          :   0 ms   (Neural Engine, real-time)
  Gate model               : 300–600 ms
  Nudge delivered to user  : 300–600 ms  ← user not waiting from here
  [Search if triggered]    : 1000–3000 ms
  Assist first token (TTFB): 500–1500 ms (after search completes)
  Assist stream duration   : 1–3 s
```
