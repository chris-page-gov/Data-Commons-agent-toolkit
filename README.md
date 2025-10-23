# Data Commons Agent Toolkit

This repo contains MCP tools and sample agents for fetching public information from [Data Commons](https://datacommons.org/).

## Docs

* [Quickstart with Gemini CLI](docs/quickstart.md)
* [User guide](docs/user_guide.md)
* [Detailed MCP Usage Guide](USAGE.md)
* [AI Agent / Copilot Instructions](.github/copilot-instructions.md)

## MCP Server

* [Data Commons MCP Server package](packages/datacommons-mcp/)
* PyPI: [datacommons-mcp](https://pypi.org/project/datacommons-mcp)

### Sample agents

* [Data Commons sample agents](packages/datacommons-mcp/examples/sample_agents)

### Starting the Server

Use the PowerShell helper script to handle venv creation, editable install, `.env` loading, and optional activation:

```powershell
# Basic HTTP mode (requires DC_API_KEY in environment or .env)
./scripts/start-server.ps1 -Mode http -Port 8080

# Stdio mode
./scripts/start-server.ps1 -Mode stdio

# Activate venv in current shell (so subsequent pip/python use the venv)
./scripts/start-server.ps1 -Mode http -Activate

# Skip API key validation (local exploration)
./scripts/start-server.ps1 -Mode http -SkipApiKeyValidation
```

Environment loading precedence:

1. Existing process environment variables
2. `.env` file (simple KEY=VALUE; quotes stripped)

If you want to use a different approach, you can still manually export `DC_API_KEY` before running the script:

```powershell
$env:DC_API_KEY = 'your-key-here'
./scripts/start-server.ps1 -Mode http -Port 8080
```

Health check endpoint:

```powershell
curl http://localhost:8080/health
```

Tool invocation example (search):

```powershell
uv run python - <<'PY'
import asyncio, httpx
async def main():
    payload = {"tool_name":"search_indicators","args":{"query":"population","places":["France"],"include_topics":False}}
    r = httpx.post("http://localhost:8080/mcp/tools/search_indicators", json=payload, timeout=30)
    print(r.status_code)
    print(r.json())
asyncio.run(main())
PY
```

