# DeepTutor — setup and running dev servers

This project is a **Python FastAPI backend** (the API) and a **Next.js frontend** (the web app). In everyday language people say “backend” and “API” for the same process: `deeptutor.api.main:app` served by Uvicorn.

Default ports (from `.env.example`; override in your root `.env`):

| Service | Role | Default port |
|--------|------|----------------|
| FastAPI / Uvicorn | REST API, WebSocket, business logic | `8001` (`BACKEND_PORT`) |
| Next.js | Browser UI | `3782` (`FRONTEND_PORT`) |

---

## Prerequisites

- **Python** 3.11+
- **Node.js** 20.9+ and **npm**
- **Git**

Windows: if native wheels fail, install [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) with **Desktop development with C++**.

---

## First-time setup

### 1. Clone and virtual environment

```bash
git clone <your-fork-or-upstream-url> DeepTutor
cd DeepTutor
```

Create a venv (example: Windows PowerShell):

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
```

macOS / Linux:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
```

### 2. Install Python dependencies (API / backend)

Install the **server** extra (FastAPI, CLI, RAG stack used by the API):

```bash
python -m pip install -e ".[server]"
```

Optional profiles (only if you need them):

```bash
python -m pip install -e ".[tutorbot]"        # TutorBot + channels
python -m pip install -e ".[tutorbot,matrix]" # + Matrix (no E2EE)
python -m pip install -e ".[all]"           # everything + dev tools
```

### 3. Install frontend dependencies

```bash
cd web
npm install
cd ..
```

### 4. Environment file

```bash
cp .env.example .env
```

Edit **`.env`** at the repo root (not only `web/`). At minimum set **LLM** variables so chat works; set **embedding** variables if you use Knowledge / RAG. See comments inside `.env.example`.

**Frontend → API URL:** Next reads `BACKEND_PORT`, `NEXT_PUBLIC_API_BASE`, and `NEXT_PUBLIC_API_BASE_EXTERNAL` from the **root** `.env` (see `web/next.config.js`). If unset, the UI defaults to `http://localhost:<BACKEND_PORT>`.

---

## Recommended: one command for both servers

After setup, from the **repo root** with the venv **activated**:

```bash
python scripts/start_web.py
```

This starts **both** the FastAPI server and the Next.js dev server, waits until they respond, and prints the **frontend URL** (usually `http://localhost:3782`). Keep this terminal open.

**First-time guided install** (dependencies, `.env` prompts, optional add-ons):

```bash
python scripts/start_tour.py
```

Then use `python scripts/start_web.py` for daily work.

**Stop** processes that were started by the launcher (when state was recorded):

```bash
python scripts/stop_web.py
```

---

## Manual: two terminals (full control)

Use separate terminals; both need the repo root context (activate the same venv for Python).

### Terminal A — API (backend)

Either:

```bash
python -m deeptutor.api.run_server
```

or (same app; port comes from `get_backend_port()` / `.env`):

```bash
deeptutor serve --reload
```

Health check: open `http://127.0.0.1:8001/` (or your `BACKEND_PORT`) — you should see a small JSON welcome payload.

### Terminal B — frontend

```bash
cd web
npm run dev -- -p 3782
```

Or use the port from `.env` (`FRONTEND_PORT`):

```bash
cd web
npm run dev -- -p %FRONTEND_PORT%   # Windows cmd
# PowerShell: npm run dev -- -p $env:FRONTEND_PORT
```

Then open **`http://localhost:3782`** in the browser.

**Turbopack (optional, more RAM):**

```bash
cd web
npm run dev:turbo -- -p 3782
```

---

## CLI equivalents

| Goal | Command |
|------|---------|
| Start web stack (frontend + API) | `python scripts/start_web.py` or `deeptutor start` |
| API only | `deeptutor serve` or `python -m deeptutor.api.run_server` |
| Interactive CLI | `deeptutor chat` / `deeptutor run …` (see `AGENTS.md`) |

---

## Production-style frontend (optional)

Build and serve Next without dev hot reload:

```bash
cd web
npm run build
npm run start
```

You still need the FastAPI process running separately (or your reverse proxy + container setup).

---

## Docker (no local Node/Python for runtime)

See **`README.md` → Option C — Docker Deployment** (`docker compose` / `docker-compose.ghcr.yml`). Configure `.env` the same way before `docker compose up`.

---

## Troubleshooting

| Symptom | What to check |
|--------|----------------|
| UI says API **404** or “Exchange failed” | Backend not running, or `NEXT_PUBLIC_API_BASE` points at the Next port by mistake. Start API on `BACKEND_PORT`; base URL should be `http://localhost:<BACKEND_PORT>`. |
| Port already in use | Change `BACKEND_PORT` / `FRONTEND_PORT` in `.env`, or stop the old process (`python scripts/stop_web.py` if you used the launcher). |
| Chat errors about API key | Set real keys in `.env` for your `LLM_BINDING` / provider; see `.env.example`. |
| After `git pull` deps drift | `python scripts/update.py` (repo helper) or reinstall: `pip install -e ".[server]"` and `cd web && npm install`. |

---

## Where to read more

- **`README.md`** — full feature overview, Docker, multi-user auth.
- **`AGENTS.md`** — architecture, capabilities, CLI entry points.
- **`.env.example`** — canonical environment variable names and sections.
