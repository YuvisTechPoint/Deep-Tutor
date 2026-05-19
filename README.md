<div align="center">

<img src="assets/logo-ver2.png" alt="DeepTutor" width="140" style="border-radius: 15px;">

# DeepTutor: Agent-Native Personalized Tutoring Platform

**Developed by [YuvisTechPoint](https://github.com/YuvisTechPoint) (Yuvraj Prasad)**

[![Python 3.11+](https://img.shields.io/badge/Python-3.11%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue?style=flat-square)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/HKUDS/DeepTutor?style=flat-square&color=brightgreen)](https://github.com/HKUDS/DeepTutor/releases)
[![arXiv](https://img.shields.io/badge/arXiv-2604.26962-b31b1b?style=flat-square&logo=arxiv&logoColor=white)](https://arxiv.org/abs/2604.26962)

</div>

---

> **Project Owner:** [YuvisTechPoint (Yuvraj Prasad)](https://github.com/YuvisTechPoint)  
> **Repository:** [Deep-Tutor](https://github.com/YuvisTechPoint/Deep-Tutor)  
> **License:** Apache 2.0

---

## Overview

DeepTutor is an advanced, agent-native intelligent tutoring platform developed by YuvisTechPoint that combines conversational AI with multi-agent reasoning to deliver personalized learning experiences. Built on a flexible two-layer plugin model (Tools and Capabilities), DeepTutor supports six distinct operational modes within a unified workspace, persistent memory systems, autonomous tutor agents (TutorBots), and comprehensive knowledge base management.

The platform is designed for individual learners, educational institutions, and organizations seeking to deploy AI-driven tutoring at scale. Features are accessible through the **FastAPI backend**, **Flutter mobile app**, **command-line interface (CLI)**, and Python SDK.

---

## Key Features

- **Unified Chat Workspace** — Six operational modes (Chat, Deep Solve, Quiz Generation, Deep Research, Math Animator, Visualize) with shared context and history
- **Multi-Agent Problem Solving** — Decompose complex problems with planning, reasoning, verification, and source citations
- **AI Co-Writer** — Multi-document Markdown workspace with intelligent rewriting, expansion, and summarization capabilities
- **Book Engine** — Automated generation of interactive "living books" with 13 specialized block types
- **Knowledge Management** — Build RAG-ready knowledge bases from PDFs, documents, and structured files
- **Persistent Memory System** — Evolving learner profiles and progress summaries shared across all features
- **Autonomous TutorBots** — Independent agents with customizable personas, multi-channel presence, and skill learning
- **Command-Line Interface** — Full feature access for automation and agent-based workflows
- **Multi-User Support** — Optional per-user workspaces with administrative resource grants and audit logging
- **Provider Flexibility** — Support for 30+ LLM providers and multiple embedding backends

---

## Architecture

DeepTutor operates on an agent-native architecture with two core plugin layers:

**Layer 1 — Tools:** Lightweight functions for RAG retrieval, web search, code execution, reasoning, brainstorming, paper search, and visualization.

**Layer 2 — Capabilities:** Multi-step agent pipelines orchestrating complex workflows. Built-in capabilities include Chat, Deep Solve, Deep Question, Deep Research, Math Animator, and Visualize.

All components are registered through discovery mechanisms and can be extended with custom tools and capabilities.

---

## Quick Start

### Requirements

- **Git** — for repository cloning
- **Python 3.11+** — API runtime
- **LLM API Key** — from providers like OpenAI, Anthropic, DeepSeek, or others
- **Windows users** — Visual Studio Build Tools with C++ workload (if not already installed)

### Installation

**Option 1: Guided Setup (Recommended)**

```bash
git clone https://github.com/YuvisTechPoint/Deep-Tutor.git
cd Deep-Tutor

# Create Python environment
python3 -m venv .venv
source .venv/bin/activate  # macOS/Linux
# or
.\.venv\Scripts\Activate.ps1  # Windows PowerShell

# Launch setup wizard
python scripts/start_tour.py
```

**Option 2: Manual Installation**

```bash
git clone https://github.com/YuvisTechPoint/Deep-Tutor.git
cd Deep-Tutor

# Create and activate environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
python -m pip install -e ".[server]"

# Configure environment
cp .env.example .env
# For a minimal local stack, use the "Local-first preset" at the end of .env.example
```

**Option 3: Docker Deployment**

```bash
cp .env.example .env   # configure keys first
docker compose up -d                    # build locally
# docker compose --profile ghcr up -d   # pre-built image
# API at http://localhost:8001
```

### Configuration

Edit `.env` (see the **Local-first preset** at the end of `.env.example` for Ollama):

```dotenv
LLM_BINDING=ollama
LLM_MODEL=llama3.2:3b-instruct
LLM_API_KEY=sk-no-key-required
LLM_HOST=http://localhost:11434/v1

EMBEDDING_BINDING=ollama
EMBEDDING_MODEL=nomic-embed-text
EMBEDDING_API_KEY=
EMBEDDING_HOST=http://localhost:11434/api/embed
EMBEDDING_DIMENSION=768
EMBEDDING_SEND_DIMENSIONS=false
```

To use a cloud provider instead, keep `.env.example` as your starting point and
swap the LLM and embedding fields to the service you want.

Recommended local setup:

```bash
ollama serve
ollama pull llama3.2:3b-instruct
ollama pull nomic-embed-text
```

Note on rate-limit fallbacks:

- **LLM_RATE_LIMIT_FALLBACK_MODEL**: if your primary LLM hits provider rate or daily token limits, DeepTutor can retry with a smaller fallback model. Set `LLM_RATE_LIMIT_FALLBACK_MODEL` in `.env` (for example `llama-3.1-8b-instant`) to enable this behaviour.


### Launch Services

```bash
python -m deeptutor.api.run_server   # API on port 8001
# or
deeptutor serve
```

API docs: `http://localhost:8001/docs`. Flutter mobile app: see `deeptutor_mobile/README.md`.

---

## Supported Providers

**LLM Providers (30+):** OpenAI, Anthropic, DeepSeek, Azure OpenAI, Gemini, Groq, Mistral, Ollama, LM Studio, llama.cpp, NVIDIA NIM, and many more.

**Embedding Providers:** OpenAI, Cohere, Jina, Ollama, vLLM, Azure OpenAI, and OpenAI-compatible services.

**Web Search Providers:** Brave, Tavily, Serper, DuckDuckGo, SearXNG, Perplexity, Jina.

See [`.env.example`](.env.example) for comprehensive configuration options.

Provider auth (`openai-codex` OAuth login; `github-copilot` validates an existing Copilot auth session) is available via `deeptutor provider login` — see the CLI package [README](deeptutor_cli/README.md).

---

## CLI Usage

```bash
# Interactive chat
deeptutor chat

# One-shot capability execution
deeptutor run chat "Explain quantum computing"
deeptutor run deep_solve "Solve the differential equation dy/dx = 2x"
deeptutor run deep_research "Machine learning optimization techniques"

# Knowledge base management
deeptutor kb create my-kb --doc document.pdf
deeptutor kb search my-kb "query terms"
deeptutor kb list

# TutorBot management
deeptutor bot create math-tutor --persona "Socratic math teacher"
deeptutor bot list

# Memory management
deeptutor memory show
deeptutor memory clear

# Session management
deeptutor session list
deeptutor session open <session_id>
```

Full CLI reference available with `deeptutor --help`.

---

## Multi-User Deployment

Enable authentication for shared deployments:

```bash
echo 'AUTH_ENABLED=true' >> .env
python -m deeptutor.api.run_server
```

1. Register the first account via `POST /api/v1/auth/register` (becomes admin)
2. Use admin API routes to provision additional accounts
3. Assign resources and permissions to each user

Admin capabilities include model management, knowledge base curation, skill assignment, and usage auditing.

---

## Documentation

All guides are in **[docs/](docs/)** — start with [docs/run.md](docs/run.md).

| Guide | Description |
|-------|-------------|
| [docs/run.md](docs/run.md) | Setup, dev servers, LLM presets, troubleshooting |
| [docs/agents.md](docs/agents.md) | Architecture (Tools + Capabilities) |
| [docs/cli-skill.md](docs/cli-skill.md) | CLI reference for AI agents |
| [docs/contributing.md](docs/contributing.md) | Contribution workflow |
| [arXiv paper](https://arxiv.org/abs/2604.26962) | Technical architecture and design principles |

## Root layout

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `.env.example` | Environment template → copy to `.env` |
| `docker-compose.yml` | Docker (profiles: `ghcr`, `dev`, `analytics`) |
| `Dockerfile` | Image build for compose |
| `deeptutor_mobile/` | Flutter Android client |
| `requirements.txt` | Python deps (`pip install -r requirements.txt`) |
| `pyproject.toml` | Python package metadata (`pip install -e ".[server]"`) |
| `.gitignore` | Git ignore rules |
| `.pre-commit-config.yaml` | Pre-commit hooks |
| `LICENSE` | Apache 2.0 |

---

## Technology Stack

- **Backend:** Python 3.11+, FastAPI, LlamaIndex, LiteLLM
- **Mobile:** Flutter (Android)
- **Agent Engine:** nanobot
- **Database:** SQLite (default), optional PocketBase sidecar
- **Containerization:** Docker, Docker Compose

---

## Roadmap

| Status | Initiative |
|:---:|:---|
| 🎯 | Multi-user authentication and account management |
| 🎯 | Customizable themes and UI appearance |
| 🔜 | Advanced memory management enhancements |
| 🔜 | LightRAG knowledge base integration |
| 🔜 | Comprehensive documentation site |

---

## License

Licensed under the [Apache License 2.0](LICENSE).

---

## Credits & Attribution

**Project Creator & Maintainer:** [YuvisTechPoint (Yuvraj Prasad)](https://github.com/YuvisTechPoint)

DeepTutor is the sole creation of YuvisTechPoint and represents a comprehensive intelligent tutoring platform built from the ground up. All code, architecture, and design decisions are attributed to YuvisTechPoint.

**Built with the following open-source projects:**
- [nanobot](https://github.com/HKUDS/nanobot) — Lightweight agent engine
- [LlamaIndex](https://github.com/run-llama/llama_index) — RAG and indexing framework
- [ManimCat](https://github.com/Wing900/ManimCat) — Mathematical animation generation

---

## Support & Community

- **GitHub Issues:** [Report bugs or request features](https://github.com/HKUDS/DeepTutor/issues)
- **GitHub Discussions:** [Community discussion forum](https://github.com/HKUDS/DeepTutor/discussions)
- **Discord:** [Community server](https://discord.gg/eRsjPgMU4t)

---

## Citation

If you use DeepTutor in your research, please cite:

```bibtex
@article{deeptutor2026,
  title={DeepTutor: Agent-Native Personalized Tutoring Platform},
  author={HKUDS},
  journal={arXiv preprint arXiv:2604.26962},
  year={2026}
}
```

