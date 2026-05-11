<div align="center">

<img src="assets/logo-ver2.png" alt="DeepTutor" width="140" style="border-radius: 15px;">

# DeepTutor: Agent-Native Personalized Tutoring Platform

[![Python 3.11+](https://img.shields.io/badge/Python-3.11%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/downloads/)
[![Next.js 16](https://img.shields.io/badge/Next.js-16-000000?style=flat-square&logo=next.js&logoColor=white)](https://nextjs.org/)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue?style=flat-square)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/HKUDS/DeepTutor?style=flat-square&color=brightgreen)](https://github.com/HKUDS/DeepTutor/releases)
[![arXiv](https://img.shields.io/badge/arXiv-2604.26962-b31b1b?style=flat-square&logo=arxiv&logoColor=white)](https://arxiv.org/abs/2604.26962)

</div>

---

## Overview

DeepTutor is an advanced, agent-native intelligent tutoring platform that combines conversational AI with multi-agent reasoning to deliver personalized learning experiences. Built on a flexible two-layer plugin model (Tools and Capabilities), DeepTutor supports six distinct operational modes within a unified workspace, persistent memory systems, autonomous tutor agents (TutorBots), and comprehensive knowledge base management.

The platform is designed for individual learners, educational institutions, and organizations seeking to deploy AI-driven tutoring at scale. All features are accessible through three entry points: a web-based interface, command-line interface (CLI), and Python SDK.

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
- **Python 3.11+** — backend runtime
- **Node.js 20.9+** — frontend runtime
- **npm** — package manager
- **LLM API Key** — from providers like OpenAI, Anthropic, DeepSeek, or others
- **Windows users** — Visual Studio Build Tools with C++ workload (if not already installed)

### Installation

**Option 1: Guided Setup (Recommended)**

```bash
git clone https://github.com/HKUDS/DeepTutor.git
cd DeepTutor

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
git clone https://github.com/HKUDS/DeepTutor.git
cd DeepTutor

# Create and activate environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
python -m pip install -e ".[server]"

cd web && npm install && cd ..

# Configure environment
cp .env.example .env
# Edit .env with your LLM provider credentials
```

**Option 3: Docker Deployment**

```bash
docker compose -f docker-compose.ghcr.yml up -d
# Access at http://localhost:3782
```

### Configuration

Edit `.env` with required variables:

```dotenv
LLM_BINDING=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=sk-xxx
LLM_HOST=https://api.openai.com/v1

EMBEDDING_BINDING=openai
EMBEDDING_MODEL=text-embedding-3-large
EMBEDDING_API_KEY=sk-xxx
EMBEDDING_HOST=https://api.openai.com/v1/embeddings
```

### Launch Services

```bash
# Automated startup
python scripts/start_web.py

# Or manual startup
python -m deeptutor.api.run_server  # Backend on port 8001
cd web && npm run dev -- -p 3782    # Frontend on port 3782
```

Access the web interface at `http://localhost:3782`.

---

## Supported Providers

**LLM Providers (30+):** OpenAI, Anthropic, DeepSeek, Azure OpenAI, Gemini, Groq, Mistral, Ollama, LM Studio, llama.cpp, NVIDIA NIM, and many more.

**Embedding Providers:** OpenAI, Cohere, Jina, Ollama, vLLM, Azure OpenAI, and OpenAI-compatible services.

**Web Search Providers:** Brave, Tavily, Serper, DuckDuckGo, SearXNG, Perplexity, Jina.

See [`.env.example`](.env.example) for comprehensive configuration options.

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
python scripts/start_web.py
```

1. Register the first account at `http://localhost:3782/register` (becomes admin)
2. Navigate to `/admin/users` to provision additional accounts
3. Assign resources and permissions to each user

Admin capabilities include model management, knowledge base curation, skill assignment, and usage auditing.

---

## Documentation

- **[Contributing Guide](CONTRIBUTING.md)** — Development setup and contribution workflow
- **[arXiv Paper](https://arxiv.org/abs/2604.26962)** — Technical architecture and design principles
- **[Environment Variables](README.md#configuration)** — Complete configuration reference

---

## Technology Stack

- **Backend:** Python 3.11+, FastAPI, LlamaIndex, LiteLLM
- **Frontend:** Next.js 16, React 19, TypeScript
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

**Creator & Maintainer:** [YuvisTechPoint](https://github.com/YuvisTechPoint)

Built with the following open-source projects:
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

