# Health-Bee

A discreet AI-powered health and wellness assistant for iOS. The user activates the app with a back-tap on their iPhone, speaks naturally, and the app listens continuously, sends transcripts to AI, and speaks replies aloud — without ever requiring the user to look at the screen.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Services](#services)
   - [Guard (Go)](#guard-go--port-8080)
   - [Backend (Node.js)](#backend-nodejs--port-3000)
   - [Agent Server (Python)](#agent-server-python--port-4000)
   - [iOS Client (Swift)](#ios-client-swift)
4. [Request Flow](#request-flow)
5. [Agent System](#agent-system)
6. [Getting Started](#getting-started)
   - [Prerequisites](#prerequisites)
   - [Environment Variables](#environment-variables)
   - [Running All Services](#running-all-services)
7. [API Reference](#api-reference)
8. [iOS Setup](#ios-setup)
9. [Development Notes](#development-notes)

---

## Architecture Overview

```
iPhone (iOS App)
      │  Bearer token
      ▼
┌─────────────┐
│  Guard      │  Go · :8080
│  (gateway)  │  Auth · Rate-limit · CORS · Routing
└──────┬──────┘
       │
       ├─── /api/*  ──────────────────────────────────►  ┌──────────────┐
       │                                                   │  Backend     │  Node.js · :3000
       │                                                   │  (Gemini     │  Chat · Streaming
       │                                                   │   proxy)     │
       │                                                   └──────────────┘
       │
       └─── /agents/*  ───────────────────────────────►  ┌──────────────┐
                                                          │  Agent       │  Python · :4000
                                                          │  Server      │  Planner · Dashboard
                                                          │              │  Coach
                                                          └──────────────┘
```

All client traffic enters through the **Guard**. No service is exposed to the public internet directly. The iOS app only ever speaks to `:8080`.

---

## Repository Structure

```
Health-Bee/
├── guard/                  Go gateway server
│   ├── main.go
│   ├── config.go
│   ├── Makefile
│   ├── go.mod
│   ├── .env.example
│   └── internal/
│       ├── auth/           Bearer token authentication
│       ├── ratelimit/      Per-client token-bucket rate limiting
│       ├── proxy/          Reverse proxy (routes to backend or agents)
│       └── middleware/     Request logging, CORS
│
├── backend/                Node.js/TypeScript Gemini proxy
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   │   ├── chat.ts     POST /api/chat, POST /api/chat/stream
│   │   │   └── health.ts   GET /health
│   │   ├── services/
│   │   │   └── gemini.ts   Google Gemini API wrapper
│   │   ├── middleware/
│   │   │   └── errorHandler.ts
│   │   └── types.ts
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
│
├── agents/                 Python/FastAPI agent server
│   ├── main.py
│   ├── config.py
│   ├── models.py           Pydantic models (mirrors AppModels.swift)
│   ├── requirements.txt
│   ├── .env.example
│   ├── agents/
│   │   ├── base.py         BaseAgent: Gemini agentic loop
│   │   ├── planner.py      Extracts todos, routines, reminders, notes
│   │   ├── dashboard.py    Generates dashboard cards
│   │   └── coach.py        Conversational health coach
│   └── routes/
│       └── agents.py       POST /agents/{planner,dashboard,coach}
│
└── client/                 Swift iOS app
    └── HealthBee/
        ├── Models/
        │   └── AppModels.swift
        └── DesignSystem/
            ├── AppTheme.swift
            ├── ThemeEnvironment.swift
            └── TypographyModifiers.swift
```

---

## Services

### Guard (Go) — port 8080

The single entry point for all client requests. Written in Go for low latency and minimal resource overhead.

**Responsibilities:**

| Layer | What it does |
|---|---|
| CORS | Preflight handling; configurable allowed origins |
| Logging | Structured JSON logs: method, path, status, duration, client |
| Auth | `Authorization: Bearer <token>` required on all routes except `/health` |
| Rate limiting | Per-client token bucket via `golang.org/x/time/rate` (default: 2 req/s, burst 10) |
| Routing | `/agents/*` → Python server; everything else → Node.js backend |
| Proxy | Strips client `Authorization` before forwarding; injects `X-Guard-Client` header |

**Key behaviours:**
- If `API_KEYS` is empty, auth is disabled (dev mode — a warning is logged per request).
- The `/health` endpoint is always public and excluded from rate limiting.
- Stale per-client rate-limit entries are evicted every 5 minutes.
- SSE (streaming) connections are proxied with `DisableCompression: true` so chunks are not buffered.

---

### Backend (Node.js) — port 3000

A TypeScript/Express server that acts as a secure server-side proxy to the Google Gemini API, keeping the API key out of the iOS app.

**Endpoints:**

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Returns `{"status":"ok"}` |
| `POST` | `/api/chat` | Full JSON response from Gemini |
| `POST` | `/api/chat/stream` | Streaming response via Server-Sent Events |

**Chat request body:**
```json
{
  "messages": [
    { "role": "user", "content": "How can I sleep better?" },
    { "role": "assistant", "content": "Try a consistent bedtime..." },
    { "role": "user", "content": "What about screen time?" }
  ],
  "systemPrompt": "You are a friendly health coach."
}
```

**Chat response:**
```json
{
  "content": "Reducing screen time 1 hour before bed...",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**SSE stream format (`/api/chat/stream`):**
```
data: {"delta":"Reducing "}
data: {"delta":"screen time "}
data: {"delta":"1 hour before bed..."}
data: [DONE]
```

**Notes:**
- Gemini's `"model"` role is mapped to/from the app's `"assistant"` role transparently.
- `systemPrompt` is passed as Gemini's `systemInstruction`, not injected as a chat message.
- Rate limit on `/api/*`: 60 req/min per IP (in addition to the guard's per-client limit).

---

### Agent Server (Python) — port 4000

A FastAPI server running specialised AI agents. Each agent uses the **Gemini function-calling (tool use) API** to produce structured output alongside a natural-language reply.

**Agentic loop (in `agents/base.py`):**

```
User message
     │
     ▼
Gemini (with tool declarations)
     │
     ├── text reply? → done
     └── tool call?  → execute tool → feed result back → repeat (max 5 rounds)
```

**Endpoints:**

| Method | Path | Agent |
|---|---|---|
| `GET` | `/health` | — |
| `POST` | `/agents/planner` | PlannerAgent |
| `POST` | `/agents/dashboard` | DashboardAgent |
| `POST` | `/agents/coach` | CoachAgent |

See [Agent System](#agent-system) for details on each agent.

---

### iOS Client (Swift)

A native SwiftUI app implementing the full-duplex voice workflow described in [gemini.md](gemini.md):

1. **Back Tap trigger** — user triple-taps the back of the iPhone; iOS Shortcuts open `my-ai-helper://listen`.
2. **Continuous listening** — `SFSpeechRecognizer` with `requiresOnDeviceRecognition: true` streams text into a live transcript buffer. A watchdog restarts the recogniser every ~60 s to work around the iOS limit.
3. **Tap to send** — when not busy, a screen tap commits the current transcript and POSTs to `/api/chat` or `/api/chat/stream` through the guard.
4. **AI reply** — response text is added to message history and spoken via AVSpeechSynthesizer. The microphone never stops.
5. **Session end** — user manually stops or the app is terminated.

**Domain models (`AppModels.swift`):**

| Type | Values |
|---|---|
| `SessionMode` | `duo`, `solo` |
| `SessionState` | `recording`, `processing`, `speaking` |
| `InsightType` | `todo`, `routine`, `note`, `reminder` |
| `DashboardCardType` | `reminder`, `social`, `insight`, `discover`, `tip` |

---

## Request Flow

### Voice chat (streaming)

```
iPhone mic
  └─ SFSpeechRecognizer (on-device)
       └─ currentTranscript buffer
            └─ [user taps] POST /api/chat/stream
                  Bearer: <token>
                  └─ Guard :8080
                       Auth ✓  Rate-limit ✓
                       └─ Proxy → Backend :3000
                            └─ Gemini API
                                 └─ SSE chunks → Guard → iPhone
                                      └─ AVSpeechSynthesizer speaks reply
```

### Planner agent (extract insights)

```
iPhone POST /agents/planner
  └─ Guard :8080
       Auth ✓  Rate-limit ✓
       └─ Proxy → Agent Server :4000
            └─ PlannerAgent
                 └─ Gemini: analyse conversation
                      └─ tool call: save_insights([...])
                           └─ response: { reply, structured: { insights: [...] } }
```

---

## Agent System

### PlannerAgent — `POST /agents/planner`

Reads the conversation and extracts structured actionable items using Gemini's `save_insights` tool call.

**Request:**
```json
{
  "messages": [{"role": "user", "content": "I need to drink more water and run tomorrow morning"}],
  "existing_insights": []
}
```

**Response:**
```json
{
  "agent": "planner",
  "reply": "I've noted two items for you: drink more water daily and go for a run tomorrow morning.",
  "structured": {
    "insights": [
      { "type": "routine", "content": "Drink more water daily", "is_completed": false },
      { "type": "todo",    "content": "Go for a run tomorrow morning", "is_completed": false }
    ]
  }
}
```

---

### DashboardAgent — `POST /agents/dashboard`

Takes the user's current insights and generates up to 5 dashboard cards using the `publish_cards` tool call. Always includes at least one `tip` card with an evidence-based health tip.

**Request:**
```json
{
  "messages": [{"role": "user", "content": "What should I focus on today?"}],
  "insights": [
    { "type": "reminder", "content": "Take medication at 8am", "is_completed": false },
    { "type": "todo",     "content": "Go for a run", "is_completed": false }
  ]
}
```

**Response:**
```json
{
  "agent": "dashboard",
  "reply": "Here's what I've prepared for your home screen today.",
  "structured": {
    "cards": [
      { "type": "reminder", "content": "Take your medication — it's 8am!" },
      { "type": "insight",  "content": "You have a run planned. Morning exercise boosts focus for hours." },
      { "type": "tip",      "content": "Drinking a glass of water first thing in the morning jumpstarts your metabolism." }
    ]
  }
}
```

---

### CoachAgent — `POST /agents/coach`

A conversational health and wellness coach. Accepts an optional `persona_prompt` to swap personality — this maps directly to the `Persona` model in the iOS app (the user's selected AI persona drives the system prompt).

**Request:**
```json
{
  "messages": [{"role": "user", "content": "I haven't been sleeping well lately."}],
  "persona_prompt": "You are Dr. Reeves, a calm and empathetic sleep specialist."
}
```

**Response:**
```json
{
  "agent": "coach",
  "reply": "I'm sorry to hear that. Poor sleep affects everything from mood to immune function. Can you tell me more — is it falling asleep that's difficult, or staying asleep?",
  "structured": null
}
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
| Google Gemini API key | — | All AI features |

### Environment Variables

**Guard (`guard/.env`):**

| Variable | Default | Description |
|---|---|---|
| `GUARD_ADDR` | `:8080` | Listen address |
| `UPSTREAM_URL` | `http://localhost:3000` | Node.js backend URL |
| `AGENT_URL` | `http://localhost:4000` | Python agent server URL |
| `API_KEYS` | *(empty = auth off)* | `token:clientName` pairs, comma-separated |
| `ALLOWED_ORIGINS` | *(empty = all)* | Comma-separated CORS origins |
| `RATE_LIMIT_RPS` | `2` | Sustained requests per second per client |
| `RATE_BURST` | `10` | Burst allowance per client |

**Backend (`backend/.env`):**

| Variable | Default | Description |
|---|---|---|
| `GEMINI_API_KEY` | *(required)* | Google Gemini API key |
| `PORT` | `3000` | Listen port |
| `ALLOWED_ORIGINS` | *(empty = all)* | Comma-separated CORS origins |

**Agent Server (`agents/.env`):**

| Variable | Default | Description |
|---|---|---|
| `GEMINI_API_KEY` | *(required)* | Google Gemini API key |
| `AGENT_SERVER_PORT` | `4000` | Listen port |
| `GUARD_URL` | `http://localhost:8080` | Guard URL (for agent → guard callbacks) |
| `GUARD_API_KEY` | *(empty)* | Bearer token agents use when calling the guard |

### Running All Services

**1. Guard**
```bash
cd guard
cp .env.example .env
# edit .env — set API_KEYS, etc.
go run .
# or: make build && ./guard
```

**2. Backend**
```bash
cd backend
cp .env.example .env
# edit .env — add GEMINI_API_KEY
npm install
npm run dev       # development (hot reload via tsx)
# or: npm run build && npm start
```

**3. Agent Server**
```bash
cd agents
cp .env.example .env
# edit .env — add GEMINI_API_KEY
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

**4. iOS Client**

Open `client/HealthBee.xcodeproj` (or `.xcworkspace`) in Xcode, set the bundle ID and signing team, then run on a physical device (microphone and back-tap require real hardware).

---

## API Reference

All requests go through the guard on port 8080. Include the Bearer token in every non-health request:

```
Authorization: Bearer <your-token>
```

### Chat endpoints (via backend)

```
GET  /health
POST /api/chat
POST /api/chat/stream
```

### Agent endpoints (via agent server)

```
GET  /health
POST /agents/planner
POST /agents/dashboard
POST /agents/coach
```

### Common response codes

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
   - Open the **Shortcuts** app → tap **+** → **Add Action** → **Open URLs**
   - Set the URL to: `my-ai-helper://listen`
   - Name the shortcut **"AI Helper"**

2. **Assign Back Tap**
   - Go to **Settings → Accessibility → Touch → Back Tap**
   - Set **Triple Tap** → **AI Helper**

3. **Grant permissions** — microphone and speech recognition when prompted on first launch.

Triple-tap the back of your iPhone anywhere, anytime. The app wakes, starts listening, and is ready.

---

## Development Notes

- **Auth in dev** — set `API_KEYS=` (empty) in the guard's `.env` to disable authentication. A warning is printed on every request.
- **Gemini model** — all three services use `gemini-1.5-flash` by default. To switch models, update `MODEL_NAME` in `backend/src/services/gemini.ts` and `gemini_model` in `agents/config.py`.
- **Agentic tool rounds** — the base agent allows up to 5 tool-call round-trips before forcing a text reply. Adjust the loop limit in `agents/agents/base.py` if needed.
- **SSE streams** — the guard sets `DisableCompression: true` on the proxy transport so SSE deltas are not held in a gzip buffer. If you add a CDN or nginx in front, ensure `X-Accel-Buffering: no` is set.
- **On-device speech recognition** — `requiresOnDeviceRecognition: true` means the app works without an internet connection for transcription, but still needs the network for Gemini. Remove this flag if you want cloud-quality recognition.
