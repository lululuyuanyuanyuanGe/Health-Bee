# Health-Bee (Wingman)

A real-time AI conversation assistant delivered through earbuds. The user activates the app with a back-tap on their iPhone, speaks naturally, and a pipeline of specialised AI agents listens continuously, reasons about the conversation, and whispers coaching cues or ready-to-speak suggestions — without ever requiring the user to look at the screen.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [The Agent System](#the-agent-system)
   - [Runtime Agents](#runtime-agents-per-session)
   - [Background Agents](#background-agents)
   - [Cross-Session Agent](#cross-session-agent)
   - [Context Builders](#conversationrecord-context-builders)
4. [Services](#services)
   - [Guard (Go)](#guard-go--port-8080)
   - [Backend (Node.js)](#backend-nodejs--port-3000)
   - [Agent Server (Python)](#agent-server-python--port-4000)
   - [iOS Client (Swift)](#ios-client-swift)
5. [LLM Provider System](#llm-provider-system)
6. [Request Flow](#request-flow)
7. [Getting Started](#getting-started)
8. [API Reference](#api-reference)
9. [iOS Setup](#ios-setup)
10. [Development Notes](#development-notes)

---

## Architecture Overview

```
iPhone (iOS App)
  Apple SpeechAnalyzer (STT, on-device, free)
  VAD silence detection  →  triggers send
  AVSpeechSynthesizer (TTS, default) | Inworld TTS (enhanced opt-in)
      │
      │  WebSocket JSON  /  Bearer token
      ▼
┌────────────────────────────────────────────────┐
│  Guard  (Go · :8080)                           │
│  Firebase JWT + API key auth                   │
│  Per-user rate limiting  ·  CORS  ·  Routing   │
└──────────────────────┬─────────────────────────┘
                       │
         ┌─────────────┼──────────────────────┐
         │             │                      │
    /api/*        /ws/wingman            /agents/*
         │             │                      │
         ▼             ▼                      ▼
  ┌────────────┐  ┌─────────────┐    ┌──────────────────┐
  │  Backend   │  │  Backend    │    │  Agent Server    │
  │  Node.js   │  │  Node.js   │    │  Python · :4000  │
  │  :3000     │  │  :3000     │    │                  │
  │  Gemini    │  │  Wingman   │    │  Planner         │
  │  proxy     │  │  pipeline  │    │  Dashboard       │
  │  (chat)    │  │  (5 agents)│    │  Coach           │
  └────────────┘  └─────────────┘    └──────────────────┘
```

All client traffic enters through the **Guard**. No downstream service is exposed publicly. The iOS app only speaks to `:8080`.

---

## Repository Structure

```
Health-Bee/
├── guard/                     Go gateway (auth, rate-limit, routing)
│   ├── main.go
│   ├── config.go
│   ├── Makefile
│   ├── go.mod
│   ├── .env.example
│   └── internal/
│       ├── auth/              Bearer token + Firebase JWT auth
│       ├── ratelimit/         Per-user token-bucket rate limiting
│       ├── proxy/             Reverse proxy (routes /agents/* vs rest)
│       └── middleware/        Structured logging, CORS
│
├── backend/                   Node.js/TypeScript — Gemini proxy + Wingman pipeline
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   │   ├── chat.ts        POST /api/chat, POST /api/chat/stream
│   │   │   └── health.ts
│   │   ├── services/
│   │   │   └── gemini.ts      Gemini API wrapper
│   │   └── types.ts
│   ├── package.json
│   └── .env.example
│
├── agents/                    Python/FastAPI — specialised agent server
│   ├── main.py
│   ├── config.py
│   ├── models.py              Pydantic models (mirrors AppModels.swift)
│   ├── requirements.txt
│   ├── agents/
│   │   ├── base.py            BaseAgent: Gemini agentic loop (ReAct)
│   │   ├── planner.py         Insight extractor (todos/routines/reminders/notes)
│   │   ├── dashboard.py       Dashboard card generator (ReAct + web search)
│   │   └── coach.py           Conversational health coach
│   └── routes/
│       └── agents.py          POST /agents/{planner,dashboard,coach}
│
└── client/                    Swift iOS app
    └── HealthBee/
        ├── Models/AppModels.swift
        └── DesignSystem/
```

---

## The Agent System

The Wingman pipeline is a set of **8 specialised agents** organised into three tiers. Each agent has a dedicated Gemini model, temperature, token budget, and prompt, tuned for its specific job.

### Runtime Agents (per session)

These run during an active conversation session.

---

#### 1. `wingman_passive` — Real-time response

The always-on responder. Generates quick, conversational replies to direct user questions in real time.

| Setting | Value |
|---|---|
| Model | `gemini-flash-lite`, temp 0.7 |
| System | `user_name` + `generated_persona` + `PASSIVE_FORMAT_RULES[session_mode][mode]` + `file_summary` |
| Human | `record.get_passive_context()` → compact prefix + transcript + user query + interleaved passive AI responses |
| Triggered by | User utterance with detected question / direct address |

**Session modes** (`session_mode` × `mode`) select different format rules:
- `solo` × `follow_mode` — longer, more expository answers
- `solo` × `insight_mode` — concise, structured insights
- `duo` × `follow_mode` — short, whisper-ready fragments
- `duo` × `insight_mode` — strategic coaching cues

---

#### 2. `wingman_gate` — Trigger decision

A cheap, fast judge that monitors the live transcript and decides whether to activate the heavy `wingman_assist` agent. Every utterance passes through the gate; `wingman_assist` only runs when the gate fires.

| Setting | Value |
|---|---|
| Model | `gemini-flash-lite`, temp 0.5, max 150 tokens |
| System | `user_name` + `WINGMAN_GATE_SYSTEM_PROMPT` + `conversation_background` |
| Human | `record.get_proactive_context()` → compact prefix + transcript + assist AI responses + metadata (context, silence duration, last assist timing) |
| Output | JSON `{"trigger": bool, "user_nudge": str}` |

The `user_nudge` string is a stalling tactic already delivered to the user while `wingman_assist` thinks (e.g. *"That's a great point, let me think about that."*). The gate does not tell assist what kind of help is needed — assist reasons that out itself from context.

---

#### 3. `wingman_assist` — Proactive big-brain (ReAct agent with tools)

The deep-thinking, high-quality response generator. Only activated when the gate fires. Has access to web search (Tavily) and reasons about whether to use it.

| Setting | Value |
|---|---|
| Model | `gemini-pro`, temp 0.9, max 600 tokens |
| System | `user_name` + `WINGMAN_ASSIST_SYSTEM_PROMPT_TEMPLATE` + `activation_context` (user_nudge from gate) + `conversation_background` |
| Human | `record.get_proactive_context()` → compact prefix + transcript + assist AI responses |
| Tools | `web_search` via Tavily (ReAct loop, max 2 rounds) |

**Output modes** — assist chooses one per activation:

| Mode | When | Rules |
|---|---|---|
| `speak_as_user` | Specific phrasing matters — a rebuttal, a deflection, a precise pitch | First person; TTS-ready; no meta-text or stage directions |
| `whisper` | Strategic insight more valuable than words — a red flag, hidden opportunity, shift in dynamic | Second person; 1-3 sentences; lead with the most important insight |

**Output format:**
```json
{
  "output_mode": "speak_as_user" | "whisper",
  "content": "..."
}
```

**ReAct search path:** When `TAVILY_API_KEY` is set, assist runs as a LangGraph `create_react_agent`. The agent decides whether to search based on context — unnecessary searches add 1–3 s latency in a live conversation, so the prompt strongly discourages searching for non-factual situations (strategy, social dynamics, emotional intelligence).

```
Gate fires
    │
    ▼
wingman_assist (LangGraph ReAct)
    │
    ├── needs a fact?  →  Tavily search  →  observe  →  [search again?]
    │                                                            │
    └── can answer from context?  ─────────────────────────────►┘
                                                                │
                                                        Final JSON response
```

**Streaming event types** (forwarded to client via Go gateway):

| Tuple | Client message | Meaning |
|---|---|---|
| `("token", text)` | `WingmanResponse.token` | LLM is streaming a token |
| `("tool_status", name)` | `WingmanResponse.status` | Tool executing (shows "Searching…" in UI) |
| `("done", full_text)` | `WingmanResponse.done` | Stream complete |
| `("error", message)` | `WingmanResponse.error` | Error; session continues |

If `TAVILY_API_KEY` is absent the agent falls back to a plain `llm.astream()` call — identical client experience, no search.

---

#### 4. `wingman_compactor` — Transcript compaction

Keeps the context window manageable for long sessions. Triggered automatically when the rolling transcript exceeds 24,000 words (~32k tokens).

| Setting | Value |
|---|---|
| Model | `gemini-flash-lite`, temp 0.2, max 3000 tokens |
| System | `WINGMAN_CONVERSATION_COMPACT_PROMPT` |
| Human | `record.get_compact_input()` + compaction instruction |
| Triggered | When word count > 24,000 |

The compactor replaces the raw transcript with a dense summary, preserving all semantically significant content. The result is stored as the new `compact_prefix` in the session record. Live agents always receive: compact prefix + recent raw transcript (only the portion since last compaction).

---

#### 5. `wingman_end_summary` — Conversation end summary

Runs once when the WebSocket disconnects. Produces a durable record of the session and updates the user's long-term memory.

| Setting | Value |
|---|---|
| Model | `gemini-flash-lite`, temp 0.3, max 2000 tokens |
| System | `WINGMAN_CONVERSATION_END_SUMMARY_PROMPT` |
| Human | `existing_user_memory` (XML) + `conversation_transcript` (XML) |
| Triggered | On WebSocket disconnect |
| Output | XML: `<conversation_title>`, `<conversation_recap>`, `<user_memory>` |

After completion, triggers the **dashboard agent** to refresh the user's home screen cards.

---

### Background Agents

These run asynchronously when a Wingman Background is created or updated, not during a live session.

---

#### 6. `wingman_file_summarizer` — File extraction

Processes uploaded attachments (images, PDFs) into a compact `file_summary` stored on the background record. The summary is injected into the passive agent's system prompt for every future session using that background.

| Setting | Value |
|---|---|
| Model | `gemini-pro`, temp 0.3 |
| System | `FILE_SUMMARIZER_PROMPT` |
| Human | Instruction text + file data URIs (multimodal) |
| Triggered | When attachments provided on background create/update |
| Output | Extracted facts → `wingman_background.file_summary` |

---

#### 7. `wingman_persona_gen` — Scenario persona generation

Generates a detailed persona and coaching style tailored to the specific scenario described in the background. The generated persona becomes the personality layer for `wingman_passive` and `wingman_assist` in every session that uses this background.

| Setting | Value |
|---|---|
| Model | `gemini-pro`, temp 0.7 |
| System | `PERSONA_GENERATION_SYSTEM_PROMPT` |
| Human | `conversation_background` + `file_summary` (if available) |
| Triggered | On background create/update (after file summarizer, if attachments present) |
| Output | Persona guidance text → `wingman_background.generated_persona` |

---

### Cross-Session Agent

#### 8. `dashboard` — Dashboard card generator (ReAct agent with tools)

Generates the user's home screen cards by synthesising their long-term memory and recent session recaps. Has web search access to surface time-sensitive content (news, weather, reminders tied to current events).

| Setting | Value |
|---|---|
| Model | `gemini-2.5-flash`, temp 0.5, max 1500 tokens |
| System | `DASHBOARD_AGENT_PROMPTS` (card types, priority order, output rules, tone) |
| Human | `current_time` + `user_memory` (from `user_memory` table) + `recent_recaps` (last 7 days from `session_recaps`, formatted as `[timestamp] title\nrecap`) |
| Tools | `web_search` (DuckDuckGo, via ReAct loop) |
| Triggered | After `wingman_end_summary` completes + daily cron at 06:00 |
| Output | 3–6 cards, one per line: `[type] content` |

**Card types** (priority order):

| Type | Purpose |
|---|---|
| `reminder` | Time-sensitive tasks, upcoming events |
| `social` | Relationship nudges, follow-up cues |
| `insight` | Patterns detected from recent sessions |
| `discover` | Curated content relevant to user's context |
| `tip` | Evidence-based health/wellness tips (always at least one) |

---

### ConversationRecord Context Builders

The `ConversationRecord` object is the session's single source of truth. All agents call one of these methods to get their human-turn input — the choice determines what each agent can see.

| Method | Contents | Used by |
|---|---|---|
| `get_transcript()` | compact prefix + raw transcript | insights extraction |
| `get_passive_context()` | compact prefix + transcript + user query + passive AI responses | `wingman_passive` |
| `get_proactive_context()` | compact prefix + transcript + assist AI responses + metadata | `wingman_gate`, `wingman_assist` |
| `get_compact_input()` | compact prefix + transcript + assist AI responses | `wingman_compactor`, `wingman_end_summary` |

**Interleaving** — passive and assist responses are woven into the transcript at the turn they were generated, so agents always see the full conversation as it actually happened, including prior AI injections.

---

### Session-Cached Fields

These are fetched once at session start and held in memory for the session lifetime:

| Field | Source | Used by |
|---|---|---|
| `user_name` | `users` table | All agents (system prompt personalisation) |
| `generated_persona` | `wingman_background` table | `wingman_passive`, `wingman_assist` |
| `file_summary` | `wingman_background` table | `wingman_passive` |
| `conversation_background` | Client WebSocket init message | `wingman_gate`, `wingman_assist`, `wingman_persona_gen` |
| `session_mode` | Client (`"solo"` \| `"duo"`) | `wingman_passive` (format rules) |
| `mode` | Client (`"follow_mode"` \| `"insight_mode"`) | `wingman_passive` (format rules) |

---

## Services

### Guard (Go) — port 8080

Single entry point for all client traffic.

| Layer | Detail |
|---|---|
| Auth | Firebase JWT (verified UID) OR shared API key. `/health` always public. |
| Rate limiting | Per-user sliding window: 40 req/60s for `/ws/wingman`, 60 req/60s for `/api/*`, 5 conn/60s for `/ws/stt` |
| Routing | `/agents/*` → Python agent server; `/ws/*` → Node.js WebSocket; `/api/*` → Node.js HTTP |
| Proxy | Strips `Authorization` before forwarding; injects `X-Guard-Client` and `X-Verified-User-ID` |
| Logging | Structured JSON: method, path, status, duration, client, remote IP |

---

### Backend (Node.js) — port 3000

TypeScript/Express server. Two responsibilities: Gemini chat proxy and Wingman WebSocket pipeline.

**HTTP endpoints:**

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | `{"status":"ok"}` |
| `POST` | `/api/chat` | Full Gemini JSON response |
| `POST` | `/api/chat/stream` | Streaming SSE response |

**WebSocket endpoints:**

| Path | Description |
|---|---|
| `/ws/wingman` | Full-duplex Wingman session (gate → passive → assist pipeline) |
| `/ws/stt` | Real-time speech-to-text proxy to ElevenLabs Scribe v2 |

**SSE stream format** (`/api/chat/stream`):
```
data: {"delta":"Reducing screen "}
data: {"delta":"time before bed..."}
data: [DONE]
```

---

### Agent Server (Python) — port 4000

FastAPI server running the three HTTP-accessible agents (Planner, Dashboard, Coach). These are the structured-output agents exposed for explicit client calls, distinct from the real-time Wingman pipeline agents above.

| Method | Path | Agent | Output |
|---|---|---|---|
| `GET` | `/health` | — | `{"status":"ok","agents":[...]}` |
| `POST` | `/agents/planner` | PlannerAgent | Structured `insights[]` |
| `POST` | `/agents/dashboard` | DashboardAgent | Structured `cards[]` |
| `POST` | `/agents/coach` | CoachAgent | Conversational reply |

All three use the Gemini function-calling (tool use) API internally — they produce structured data by having the model call a declared tool rather than by parsing free text.

---

### iOS Client (Swift)

Native SwiftUI app. STT and TTS run entirely on-device (Apple Neural Engine + AVSpeechSynthesizer), so the backend is text-in / text-out only.

**Full-duplex voice workflow:**

1. **Back Tap trigger** — triple-tap the back of the iPhone; iOS Shortcuts open `my-ai-helper://listen`
2. **Continuous listening** — `SFSpeechRecognizer` with `requiresOnDeviceRecognition: true` streams text into a live `currentTranscript` buffer; a watchdog restarts the recogniser every ~60 s
3. **Tap to send** — when not busy, a screen tap commits the transcript and sends it over the Wingman WebSocket
4. **AI reply** — streamed tokens arrive; `AVSpeechSynthesizer` speaks them; microphone never stops
5. **Session end** — user manually stops or app terminates; `wingman_end_summary` runs on disconnect

**Domain models (`AppModels.swift`):**

| Type | Values |
|---|---|
| `SessionMode` | `duo`, `solo` |
| `SessionState` | `recording`, `processing`, `speaking` |
| `InsightType` | `todo`, `routine`, `note`, `reminder` |
| `DashboardCardType` | `reminder`, `social`, `insight`, `discover`, `tip` |

---

## LLM Provider System

All model assignments live in `service/llm_providers/providers.json`. Switching models for any agent requires only a config edit and restart — no code changes.

**Model roles:**

| Role | Default model | Temp | Notes |
|---|---|---|---|
| `wingman_passive` | `gemini-flash-lite-latest` | 0.7 | Streaming |
| `wingman_gate` | `gemini-flash-lite-latest` | 0.5 | JSON output, max 150 tokens |
| `wingman_assist` | `gemini-3-pro-preview` | 0.9 | ReAct + streaming, max 600 tokens |
| `wingman_summarizer` | `gemini-flash-lite-latest` | 0.2 | Max 3000 tokens |
| `insights` | `gemini-2.0-flash-lite` | 0.3 | Structured JSON |
| `url_summarizer` | `gemini-2.5-flash` | 0.3 | Multimodal |
| `copilot_chat` | `gemini-flash-lite-latest` | 0.7 | Tool binding + streaming |

**Supported providers** (all via LangChain, no code change needed for OpenAI-compatible ones):

| Provider | Class | Notes |
|---|---|---|
| `google` | `ChatGoogleGenerativeAI` | Default |
| `anthropic` | `ChatAnthropic` | claude-sonnet-4-6, claude-opus-4-6 |
| `deepseek` | `ChatOpenAI` | Do not use `deepseek-reasoner` for tool-calling roles |
| `moonshot` | `ChatOpenAI` | Kimi models, 256K context |
| `qwen` | `ChatOpenAI` | DashScope US endpoint; limited model catalog |
| `glm` | `ChatOpenAI` | Zhipu GLM via Z.AI |
| `minimax` | `ChatOpenAI` | MiniMax M2.5 |
| `grok` | `ChatOpenAI` | xAI, 2M context on grok-4-1 variants |
| `openai_compatible` | `ChatOpenAI` | Generic; set `OPENAI_BASE_URL` |

**Mixing providers across roles:**
```json
{
  "roles": {
    "wingman_assist":  { "provider": "anthropic", "model": "claude-sonnet-4-6",    "temperature": 0.9, "max_tokens": 600 },
    "wingman_passive": { "provider": "google",    "model": "gemini-flash-lite-latest", "temperature": 0.7 },
    "insights":        { "provider": "deepseek",  "model": "deepseek-chat",         "temperature": 0.3 }
  }
}
```

---

## Request Flow

### Wingman session (full-duplex)

```
iPhone mic
  └─ Apple SpeechAnalyzer (on-device STT)
       └─ VAD silence detection
            └─ WS send utterance
                  │  /ws/wingman  Bearer: <token>
                  ▼
            Guard :8080  (auth ✓, rate-limit ✓)
                  │
                  ▼  WebSocket proxy
            Backend :3000 — Wingman pipeline
                  │
                  ├─ wingman_passive ──► stream tokens ──► Guard ──► iPhone TTS
                  │
                  ├─ wingman_gate ──► {trigger: true, user_nudge: "..."}
                  │       │
                  │       └─ wingman_assist (ReAct)
                  │               ├─ Tavily search? ──► {"status":"processing_tool"}
                  │               └─ stream tokens ──► Guard ──► iPhone TTS
                  │
                  └─ [on disconnect] wingman_end_summary
                                          └─ dashboard agent refresh
```

### Proactive assist — search path

```
Client receives:
  {"type":"proactive_assist","trigger":"factual_dispute","confidence":0.85}
  {"status":"processing_tool","tool":"tavily_search"}
  {"type":"token","token":"The correct figure is approximately 4.2 billion,"}
  {"type":"token","token":" based on recent reports."}
  {"type":"done"}
```

### Proactive assist — no search

```
Client receives:
  {"type":"proactive_assist","trigger":"question_directed","confidence":0.91}
  {"type":"token","token":"The capital of France is Paris."}
  {"type":"done"}
```

---

## Getting Started

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Go | ≥ 1.22 | Guard server |
| Node.js | ≥ 18 | Backend server |
| Python | ≥ 3.11 | Agent server |
| Xcode | ≥ 15 | iOS client |
| Google Gemini API key | — | All AI features (required) |
| Tavily API key | — | Web search in `wingman_assist` and `dashboard` (optional) |

### Environment Variables

**Guard (`guard/.env`):**

| Variable | Default | Description |
|---|---|---|
| `GUARD_ADDR` | `:8080` | Listen address |
| `UPSTREAM_URL` | `http://localhost:3000` | Node.js backend |
| `AGENT_URL` | `http://localhost:4000` | Python agent server |
| `API_KEYS` | *(empty = auth off)* | `token:clientName` pairs, comma-separated |
| `FIREBASE_PROJECT_ID` | *(optional)* | Enable Firebase JWT auth |
| `ALLOWED_ORIGINS` | *(empty = all)* | CORS origins |
| `RATE_LIMIT_RPS` | `2` | Sustained req/s per client |
| `RATE_BURST` | `10` | Burst allowance |

**Backend (`backend/.env`):**

| Variable | Default | Description |
|---|---|---|
| `GEMINI_API_KEY` | *(required)* | Gemini API key |
| `PORT` | `3000` | Listen port |
| `ELEVENLABS_API_KEY` | *(optional)* | Enables `/ws/stt` |

**Agent Server (`agents/.env`):**

| Variable | Default | Description |
|---|---|---|
| `GEMINI_API_KEY` | *(required)* | Gemini API key |
| `AGENT_SERVER_PORT` | `4000` | Listen port |
| `TAVILY_API_KEY` | *(optional)* | Enables web search in assist + dashboard |
| `GUARD_URL` | `http://localhost:8080` | Guard base URL |
| `GUARD_API_KEY` | *(empty)* | Token agents use when calling the guard |

### Running All Services

**1. Guard**
```bash
cd guard
cp .env.example .env   # edit: set API_KEYS
go run .
# or: make build && ./guard
```

**2. Backend**
```bash
cd backend
cp .env.example .env   # edit: add GEMINI_API_KEY
npm install
npm run dev            # hot reload via tsx
# or: npm run build && npm start
```

**3. Agent Server**
```bash
cd agents
cp .env.example .env   # edit: add GEMINI_API_KEY, optionally TAVILY_API_KEY
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

**4. iOS Client**

Open `client/HealthBee.xcodeproj` in Xcode, set signing team, run on a physical device (microphone and back-tap require real hardware).

---

## API Reference

All requests go through the guard on `:8080`. Include the Bearer token on every non-health request:

```
Authorization: Bearer <your-token>
```

### HTTP

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Guard health (no auth) |
| `GET` | `/api/health` | Python service health (no auth) |
| `POST` | `/api/chat` | Gemini chat (full response) |
| `POST` | `/api/chat/stream` | Gemini chat (SSE streaming) |
| `POST` | `/api/wingman/background` | Create wingman background (triggers persona gen) |
| `PUT` | `/api/wingman/background/:id` | Update background + attachments |
| `GET` | `/api/wingman/background` | List user's backgrounds |
| `POST` | `/agents/planner` | Extract insights from conversation |
| `POST` | `/agents/dashboard` | Generate dashboard cards |
| `POST` | `/agents/coach` | Conversational coach (Persona-driven) |

### WebSocket

| Path | Description |
|---|---|
| `/ws/wingman?api_key=...` | Full-duplex Wingman session |
| `/ws/stt?api_key=...` | Real-time STT (ElevenLabs proxy) |

### Agent request/response shape

```json
// Request
{
  "messages": [{"role": "user", "content": "I need to drink more water"}],
  "existing_insights": [],      // planner only
  "insights": [...],            // dashboard only
  "persona_prompt": "..."       // coach only
}

// Response
{
  "agent": "planner",
  "reply": "I've noted that for you.",
  "structured": {
    "insights": [
      {"type": "routine", "content": "Drink more water daily", "is_completed": false}
    ]
  }
}
```

### Common status codes

| Code | Meaning |
|---|---|
| `200` | Success |
| `400` | Invalid request body |
| `401` | Missing or invalid Bearer token |
| `429` | Rate limit exceeded |
| `500` | Internal agent/backend error |
| `502` | Upstream service unavailable |

---

## iOS Setup

After installing the app on your iPhone:

1. **Create the Shortcut**
   - Open **Shortcuts** → tap **+** → **Add Action** → **Open URLs**
   - URL: `my-ai-helper://listen`
   - Name: **"AI Helper"**

2. **Assign Back Tap**
   - **Settings → Accessibility → Touch → Back Tap**
   - **Triple Tap** → **AI Helper**

3. **Grant permissions** — microphone and speech recognition on first launch.

Triple-tap the back of your iPhone anywhere, anytime. The app wakes, the pipeline starts, and you're covered.

---

## Development Notes

- **Auth in dev** — leave `API_KEYS=` empty in guard's `.env` to disable authentication. A warning logs on every request.
- **Search in dev** — omit `TAVILY_API_KEY` entirely; `wingman_assist` and `dashboard` fall back to plain LLM calls with no code change.
- **Switching models** — edit `service/llm_providers/providers.json`, restart Python service. No code change needed for any OpenAI-compatible provider.
- **`create_react_agent` note** — the agent server uses `langgraph.prebuilt.create_react_agent` (not the newer `langchain.agents.create_agent`) due to open bugs in the replacement affecting Gemini + streaming. Revisit when [langchain#34613](https://github.com/langchain-ai/langchain/issues/34613) is resolved.
- **Streaming with tools** — `astream_events(version="v2")` is used instead of `stream_mode="messages"` to work around a LangGraph token-buffering bug ([langgraph#5249](https://github.com/langchain-ai/langgraph/issues/5249)) that surfaces when tools are bound.
- **SSE streams** — guard sets `DisableCompression: true` on the proxy transport; ensure `X-Accel-Buffering: no` is set if you add nginx or a CDN.
- **On-device STT** — `requiresOnDeviceRecognition: true` means transcription works offline. Remove the flag for cloud-quality recognition at the cost of privacy and an extra network round-trip.
- **Context window management** — the compactor triggers at 24,000 words. For very long sessions adjust the threshold in `wingman_handler.py`.
- **Gemini 2.0 retirement** — `gemini-2.0-flash` and `gemini-2.0-flash-lite` retire June 1 2026. Update `providers.json` before that date.
