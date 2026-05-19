# ============================================
# DeepTutor Backend Dockerfile
# ============================================
# Build: docker compose build
# Run:   docker compose up -d
#
# Prerequisites:
#   1. Copy .env.example to .env and configure your API keys
#   2. Runtime settings are created under data/user/settings on first start
# ============================================

FROM python:3.11-slim AS python-base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

COPY requirements/ ./requirements/
COPY requirements.txt ./
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

FROM python:3.11-slim AS production

ARG APP_VERSION=""

LABEL maintainer="DeepTutor Team" \
      description="DeepTutor: AI-Powered Personalized Learning Assistant (API)" \
      version="1.0.0"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    APP_VERSION=${APP_VERSION} \
    BACKEND_PORT=8001

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bash \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=python-base /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=python-base /usr/local/bin /usr/local/bin

COPY deeptutor/ ./deeptutor/
COPY deeptutor_cli/ ./deeptutor_cli/
COPY scripts/ ./scripts/
COPY pyproject.toml ./
COPY requirements/ ./requirements/
COPY requirements.txt ./

RUN mkdir -p \
    data/user/settings \
    data/memory \
    data/user/workspace/memory \
    data/user/workspace/notebook \
    data/user/workspace/co-writer/audio \
    data/user/workspace/co-writer/tool_calls \
    data/user/workspace/chat/chat \
    data/user/workspace/chat/deep_solve \
    data/user/workspace/chat/deep_question \
    data/user/workspace/chat/deep_research/reports \
    data/user/workspace/chat/math_animator \
    data/user/workspace/chat/_detached_code_execution \
    data/user/logs \
    data/knowledge_bases

RUN cat > /app/start-backend.sh <<'EOF'
#!/bin/bash
set -e

BACKEND_PORT=${BACKEND_PORT:-8001}

echo "[Backend] Starting FastAPI on port ${BACKEND_PORT}..."
exec python -m uvicorn deeptutor.api.main:app --host 0.0.0.0 --port ${BACKEND_PORT}
EOF

RUN sed -i 's/\r$//' /app/start-backend.sh && chmod +x /app/start-backend.sh

RUN cat > /app/entrypoint.sh <<'EOF'
#!/bin/bash
set -e

export BACKEND_PORT=${BACKEND_PORT:-8001}

echo "============================================"
echo "Starting DeepTutor API"
echo "============================================"
echo "Backend port: ${BACKEND_PORT}"

if [ -z "$LLM_API_KEY" ]; then
    echo "Warning: LLM_API_KEY not set"
fi

if [ -z "$LLM_MODEL" ]; then
    echo "Warning: LLM_MODEL not set"
fi

python -c "
from pathlib import Path
from deeptutor.services.setup import init_user_directories
init_user_directories(Path('/app'))
" 2>/dev/null || echo "Directory initialization skipped (created on first use)"

exec /app/start-backend.sh
EOF

RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${BACKEND_PORT:-8001}/ || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]

FROM production AS development

RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir pre-commit black ruff

RUN cat > /app/start-backend.sh <<'EOF'
#!/bin/bash
set -e

BACKEND_PORT=${BACKEND_PORT:-8001}
exec python -m uvicorn deeptutor.api.main:app --host 0.0.0.0 --port ${BACKEND_PORT} --reload
EOF

RUN sed -i 's/\r$//' /app/start-backend.sh && chmod +x /app/start-backend.sh

EXPOSE 8001
