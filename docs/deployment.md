# Deployment

DeepTutor ships as a **Python FastAPI API**. Clients (Flutter mobile app, CLI, automation) connect to `deeptutor.api.main:app`.

## Docker (recommended)

```bash
cp .env.example .env   # configure LLM_* keys
docker compose up -d
```

The API listens on **`BACKEND_PORT`** (default `8001`). Set `CORS_ORIGIN` / `CORS_ORIGINS` when browsers or mobile web views call the API from another origin.

```bash
docker compose --profile ghcr up -d   # pre-built image
docker compose --profile dev up -d    # hot-reload backend
```

## Bare metal / VM

```bash
python -m pip install -e ".[server]"
python -m deeptutor.api.run_server
```

Or: `deeptutor serve --reload` for development.

## Environment

Use the same variables as local development (see [run.md](run.md) and [`.env.example`](../.env.example)). Required for a working stack:

- `LLM_BINDING`, `LLM_MODEL`, `LLM_API_KEY`, `LLM_HOST`
- Embedding variables when using knowledge bases / RAG

For public hosting, also set:

- `AUTH_ENABLED=true` and `AUTH_SECRET`
- `CORS_ORIGINS` for your client app origins
- `AUTH_COOKIE_SECURE=true` when serving over HTTPS

## Health check

`GET /` on the API port should return successfully. Docker Compose uses this for container health.

See also [run.md](run.md) and [README.md](../README.md).
