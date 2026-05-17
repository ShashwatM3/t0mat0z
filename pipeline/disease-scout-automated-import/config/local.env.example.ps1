# Copy commands from this file into your local PowerShell session.
# Do not commit real API keys.

# Existing local proxy modes:
$env:DISEASE_SCOUT_MODEL_PROVIDER = "codex-cli"
# $env:DISEASE_SCOUT_MODEL_PROVIDER = "openai"
# $env:DISEASE_SCOUT_MODEL_PROVIDER = "gemini"

# Optional OpenAI Responses API path:
# $env:OPENAI_API_KEY = Get-Secret OPENAI_API_KEY -AsPlainText
$env:OPENAI_MODEL = "gpt-4.1-mini"

# Optional Gemini path:
# $env:GEMINI_API_KEY = Get-Secret GEMINI_API_KEY -AsPlainText
$env:DISEASE_SCOUT_GEMINI_MODEL = "gemini-2.5-flash-lite"

# Codex CLI bridge settings:
$env:DISEASE_SCOUT_CODEX_MODEL = "gpt-5.5"
$env:DISEASE_SCOUT_CODEX_REASONING_EFFORT = "low"
$env:DISEASE_SCOUT_CODEX_TIMEOUT_MS = "180000"

# API server and phone/web routing:
$env:DISEASE_SCOUT_API_PORT = "8787"
# $env:EXPO_PUBLIC_DISEASE_SCOUT_API_URL = "http://<laptop-lan-ip>:8787/api/scout/analyze"
