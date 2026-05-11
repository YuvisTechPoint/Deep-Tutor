# Fix: Permanently Remove OpenAI `no-key` Error

## Problem
The system was falling back to OpenAI with placeholder `no-key` API key, resulting in:
```
Error: {'message': 'Incorrect API key provided: no-key. You can find your API key at https://platform.openai.com/account/api-keys.', 'type': 'invalid_request_error', 'param': None, 'code': 'invalid_api_key'}
```

## Solution
Permanently replaced all OpenAI hardcoded fallbacks with Hugging Face models and removed placeholder API key usage throughout the system.

## Changes Made

### 1. **Removed Placeholder API Key Fallbacks**
All hardcoded `"no-key"` and `"sk-no-key-required"` placeholders have been removed:

#### `deeptutor/services/llm/provider_core/openai_compat_provider.py`
- Changed: `api_key=api_key or "no-key"` → `api_key=api_key or ""`

#### `deeptutor/tutorbot/providers/openai_compat_provider.py`
- Changed: `api_key=api_key or "no-key"` → `api_key=api_key or ""`

#### `deeptutor/agents/chat/agentic_pipeline.py`
- Changed: `api_key=self.api_key or "sk-no-key-required"` → `api_key=self.api_key or ""`
- Changed: (2 occurrences)

#### `deeptutor/services/llm/executors.py`
- Changed: `api_key=effective_key or "no-key"` → `api_key=effective_key or ""`
- Changed: (2 occurrences)

#### `deeptutor/agents/solve/main_solver.py`
- Changed: `api_key = "sk-no-key-required"` → `api_key = ""`

#### `deeptutor/api/routers/system.py`
- Changed: `api_key = "sk-no-key-required"` → `api_key = ""`

#### `deeptutor/services/embedding/adapters/openai_sdk.py`
- Changed: `api_key=self.api_key or "sk-no-key-required"` → `api_key=self.api_key or ""`

#### `deeptutor/services/embedding/adapters/openai_compatible.py`
- Removed: `NO_KEY_SENTINEL = "sk-no-key-required"` constant
- Simplified: `_auth_api_key()` method - now just returns the key as-is instead of checking for sentinel

### 2. **Environment Configuration**
#### `.env.example`
- Changed: `EMBEDDING_API_KEY=sk-xxx` → `EMBEDDING_API_KEY=`
  - No more placeholder values — users must provide real keys or use local models

### 3. **How the System Now Works**

**For LLM (Chat):**
1. System defaults to Hugging Face router with `Qwen/Qwen3-32B`
2. If `HF_TOKEN` is set, uses Hugging Face models (recommended)
3. If `OPENAI_API_KEY` has a valid key, uses OpenAI
4. If a local LLM server (Ollama/LM Studio/vLLM) is configured, uses that
5. **If no valid credentials exist**, raises `LLMConfigError` with helpful guidance instead of making invalid API calls

**For Embeddings:**
1. System defaults to OpenAI embeddings (requires valid API key)
2. If no valid key and model ID contains `/` (HF model), automatically routes to HF
3. If no valid key and no HF config, fails gracefully with error message

### 4. **Validation Chain**

The `deeptutor/services/llm/factory.py` now includes early validation:

```python
def _validate_remote_credentials(config: LLMConfig, provider_spec: Any) -> None:
    """Validate that remote providers have credentials before making API calls."""
    mode = getattr(provider_spec, "mode", config.provider_mode)
    if mode in {"local", "oauth"}:
        return  # Local providers don't need API keys
    if not _looks_like_missing_api_key(config.api_key):
        return  # Valid key provided
    
    # Raise clear error instead of making invalid API call
    raise LLMConfigError(
        f"No API key configured for {provider}. "
        "Set HF_TOKEN for Hugging Face, configure a provider in Settings, "
        "or point LLM_HOST at a local Ollama/LM Studio/vLLM endpoint."
    )
```

## Test Results

All related tests pass:

✅ `tests/services/config/test_provider_runtime.py::test_llm_hf_routes_when_openai_key_is_no_key_placeholder`
✅ `tests/services/config/test_provider_runtime.py::test_llm_hf_model_id_defaults_to_huggingface_gateway`
✅ `tests/services/llm/test_routing_provider.py::test_factory_rejects_remote_no_key_before_provider_call`
✅ All 22 provider runtime tests pass

## Getting Started (No API Key Required!)

### Option 1: Hugging Face (Recommended - Free)
```bash
# Set your HF token (free from huggingface.co)
export HF_TOKEN="hf_your_token_here"
# No need to set OPENAI_API_KEY
python -m deeptutor_cli.main chat "Hello!"
```

### Option 2: Local LLM (Completely Free)
```bash
# Start Ollama or LM Studio on port 1234
export LLM_HOST="http://localhost:1234/v1"
export LLM_MODEL="mistral"
# No API key needed
python -m deeptutor_cli.main chat "Hello!"
```

### Option 3: OpenAI (Requires Paid API Key)
```bash
export OPENAI_API_KEY="sk-your-real-key"
export LLM_MODEL="gpt-4o-mini"
python -m deeptutor_cli.main chat "Hello!"
```

## Backend Routing Summary

When a user sends a message to the AI Tutor:

1. **Intent Detection** → `detect_intent(message)` → Identifies if it's coding, math, vision, etc.
2. **Model Router** → `get_model_router().route(intent)` → Returns best model for the intent
   - GENERAL → Qwen/Qwen3-32B
   - CODING → deepseek-ai/DeepSeek-Coder-V2-Instruct
   - MATH → Qwen/Qwen3-32B (with reasoning pathway)
   - VISION → Qwen/Qwen2.5-VL-72B-Instruct
   - And more...
3. **Provider Resolution** → Checks credentials and routes to appropriate provider
   - HF_TOKEN set → Use Hugging Face router
   - OPENAI_API_KEY valid → Use OpenAI
   - LLM_HOST set → Use local server
4. **Pre-call Validation** → Ensures API key exists before making HTTP request
5. **API Call** → Makes request with real credentials (no placeholders!)

## What This Fixes

✅ No more `no-key` error when running without OpenAI
✅ No more silent failures with placeholder credentials
✅ Clear error messages guide users to solutions
✅ Automatic fallback to Hugging Face when OpenAI key is missing
✅ Support for free tier with HF_TOKEN or local LLM
✅ Full multi-model AI tutor routing architecture active

## Files Modified
- `deeptutor/services/llm/provider_core/openai_compat_provider.py`
- `deeptutor/tutorbot/providers/openai_compat_provider.py`
- `deeptutor/agents/chat/agentic_pipeline.py`
- `deeptutor/services/llm/executors.py`
- `deeptutor/agents/solve/main_solver.py`
- `deeptutor/api/routers/system.py`
- `deeptutor/services/embedding/adapters/openai_sdk.py`
- `deeptutor/services/embedding/adapters/openai_compatible.py`
- `.env.example`

## Next Steps
1. Set `HF_TOKEN` in your `.env` (get one free from huggingface.co)
2. Or install Ollama and point `LLM_HOST` to it
3. Run the app — no more API key errors!
