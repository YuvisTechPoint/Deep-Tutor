# Code Lab

Code Lab (`/coding-practice`) generates coding challenges, runs sample tests, and awards XP on full submission. Problems can be LLM-generated or served from an offline bank.

## Quick test (offline)

```bash
export CODE_LAB_DISABLE_LLM=1   # Windows PowerShell: $env:CODE_LAB_DISABLE_LLM = "1"
python -m deeptutor.api.run_server
```

Open **Code Lab** in the UI — problems load from the offline bank immediately.

## Environment

| Variable | Purpose |
|----------|---------|
| `CODE_LAB_DISABLE_LLM=1` | Force offline problem generation |
| `CODE_LAB_GENERATION_TIMEOUT_SEC` | LLM generation timeout (default 15s) |
| `LLM_MODEL_CODING_PRACTICE` | Model for Code Lab (highest priority) |
| `LLM_MODEL_PRACTICE` | Fallback if coding-specific model unset |

## Model selection

Resolution order (`deeptutor/services/coding_practice/generator.py`):

1. `LLM_MODEL_CODING_PRACTICE`
2. `LLM_MODEL_PRACTICE`
3. Model router feature `practice_coding`
4. Default: `llama-3.1-70b-versatile`

Example (Groq):

```env
LLM_MODEL_CODING_PRACTICE=llama-3.3-70b-versatile
```

Restart the API after changing `.env`.

Verify in Python:

```python
from deeptutor.services.coding_practice.generator import _resolve_coding_practice_model
print(_resolve_coding_practice_model())
```

## Expected behavior

1. A problem loads within the generation timeout (or immediately in offline mode).
2. **Run** executes against sample tests (Python in-process; JS/C/C++/Java need toolchains).
3. **Submit** runs the full suite and awards XP when all tests pass.

## Toolchains

| Language | Requirement |
|----------|-------------|
| Python | Built-in executor |
| JavaScript | Node.js 18+ |
| C / C++ | gcc/g++ or clang |
| Java | JDK 17+ |

Check availability: `GET /api/v1/coding-practice/toolchains`

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/coding-practice/problem` | Fetch problem (`topic`, `difficulty`, `language`) |
| POST | `/api/v1/coding-practice/run` | Run against sample tests |
| POST | `/api/v1/coding-practice/submit` | Full evaluation + XP |
| GET | `/api/v1/coding-practice/toolchains` | Installed compilers/interpreters |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Stuck on "Generating your challenge…" | Set `CODE_LAB_DISABLE_LLM=1` or check API logs / LLM credentials |
| Execution fails (non-Python) | Install toolchain; call toolchains endpoint |
| XP not awarded | Ensure all tests pass; check gamification logs |

## Source layout

- Mobile UI: `deeptutor_mobile/lib/features/practice/` (MCQ); Code Lab API: `/api/v1/coding-practice`
- API: `deeptutor/api/routers/coding_practice.py`
- Generator: `deeptutor/services/coding_practice/generator.py`
- Runner: `deeptutor/services/coding_practice/runner.py`, `native_runner.py`
