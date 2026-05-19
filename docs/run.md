# DeepTutor — setup and running the API

DeepTutor is a **Python FastAPI backend** (`deeptutor.api.main:app`) served by Uvicorn. Clients include the **Flutter mobile app** (`deeptutor_mobile/`), the **CLI** (`deeptutor`), and any HTTP integration.

Default API port: **`8001`** (`BACKEND_PORT` in `.env`).

## Quick start

From the repository root (venv active, `pip install -e ".[server]"` done):

1. Copy and edit env: `cp .env.example .env`
2. Start the API:

   **Windows (PowerShell):**

   ```powershell
   Set-Location C:\path\to\Deep-Tutor
   .\.venv\Scripts\python.exe -m deeptutor.api.run_server
   ```

   **macOS / Linux:**

   ```bash
   cd /path/to/Deep-Tutor
   source .venv/bin/activate
   python -m deeptutor.api.run_server
   ```

3. Open **`http://localhost:8001/docs`** for the interactive OpenAPI UI.

Alternative: `deeptutor serve` or `deeptutor start` (same server).

First-time setup wizard: `python scripts/start_tour.py`

## First-time setup

### 1. Python environment

```bash
python3 -m venv .venv
source .venv/bin/activate          # macOS/Linux
# .\.venv\Scripts\Activate.ps1     # Windows
python -m pip install -e ".[server]"
```

### 2. Configuration

Edit **`.env`** at the repo root. Minimum for chat:

```dotenv
LLM_BINDING=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=sk-...
LLM_HOST=https://api.openai.com/v1
```

See `.env.example` and the **Local-first preset** at the end of that file for Ollama.

### 3. Guided setup (optional)

```bash
python scripts/start_tour.py
```

Writes ports and provider settings into `.env` and installs Python dependencies.

## Development

```bash
deeptutor serve --reload
# or
DEEPTUTOR_API_RELOAD=1 python -m deeptutor.api.run_server
```

Verify install: `python scripts/check_install.py`

## Docker

```bash
cp .env.example .env
docker compose up -d
```

API on port `8001` (or `BACKEND_PORT`). See [deployment.md](deployment.md).

## Authentication

With `AUTH_ENABLED=true`:

- Register first user: `POST /api/v1/auth/register`
- Login: `POST /api/v1/auth/login`
- Mobile/CLI clients send `Authorization: Bearer <token>`

## Flutter mobile client

Configure `deeptutor_mobile` to point at your API base URL (default dev: `http://10.0.2.2:8001` on Android emulator). See [flutter-android-mobile-spec.md](flutter-android-mobile-spec.md).

## Stopping the server

Press **Ctrl+C** in the terminal running Uvicorn.

**Port still busy (Windows):**

```powershell
Get-NetTCPConnection -LocalPort 8001 -State Listen | Select-Object OwningProcess
Stop-Process -Id <pid> -Force
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `LLM_API_KEY` / model errors | Check `.env` and provider dashboard |
| CORS errors from a browser client | Set `CORS_ORIGIN` or `CORS_ORIGINS` to your client origin |
| Import errors | `pip install -e ".[server]"` |
| Windows subprocess errors | Use `python -m deeptutor.api.run_server` (Proactor event loop is configured) |
