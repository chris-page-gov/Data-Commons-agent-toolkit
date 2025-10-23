# Data Commons MCP Server Usage Guide

This guide explains how the MCP server in this repository goes beyond simple API wrapping by providing higher‑level validation, place/topic reasoning, source selection, caching, and chart configuration primitives.

## 1. Overview

The server exposes two core MCP tools plus an internal chart config factory:

- `search_indicators` – Discovers candidate topics & statistical variables for one or more human‑readable places (with optional bilateral reasoning) and returns structured mappings (names, place types, data coverage).
- `get_observations` – Fetches observations for a validated variable/place (single place) or for all child places of a determined type under a parent place.
- `get_datacommons_chart_config` (internal helper) – Builds validated chart configuration objects (line, bar, map, pie, ranking, highlight, gauge) from primitive args.

Unlike a thin API proxy, the server performs semantic validation, expands topics hierarchies, samples child places, ranks sources deterministically, filters by date semantics, and returns normalized Pydantic models suitable for downstream agents.

## 2. Key Value‑Adds Beyond Raw API

1. Place & Variable Validation Workflow
   - Enforces: always call `search_indicators` first; never invent DCIDs.
   - Provides `dcid_place_type_mappings` enabling safe child place type determination for hierarchical queries.
2. Topic Expansion & Name Resolution
   - Loads cached topic graphs and produces unified `dcid_name_mappings` for human‑readable presentation.
3. Bilateral Data Handling
   - `maybe_bilateral` flag informs the search logic to differentiate variables encoding a second place inside the variable DCID (e.g., trade flows).
4. Source Selection Algorithm
   - Chooses primary source via multi‑criteria ranking: (a) places covered > (b) observation count > (c) latest date > (d) average facet index (lower better) > (e) source_id – ensuring consistent, explainable selection.
5. Date Semantics & Range Normalization
   - Supports enums (`latest|all|range`) plus partial concrete dates (`YYYY|YYYY-MM|YYYY-MM-DD`) with validation and inclusive range filtering.
6. Child Place Sampling Strategy
   - Guides agents to sample 5–6 diverse children to infer availability and child place type before bulk retrieval.
7. Caching Layer
   - LRU caching of variable existence per place prevents redundant upstream calls and accelerates iterative queries.
8. Strict Error Modeling
   - Domain exceptions (`InvalidDateFormatError`, `InvalidDateRangeError`, `DataLookupError`) surface precise validation failures.
9. Typed Output Models
   - Pydantic responses (`SearchResponse`, `ObservationToolResponse`, chart configs) eliminate ad‑hoc JSON parsing in clients.
10. Chart Configuration Factory
    - Converts primitive args into validated union models with mutually exclusive location modes (multi‑place vs hierarchy vs single place).

## 3. Usage Recipes

### 3.1 Find a Variable for a Single Place

```bash
search_indicators(query="population", places=["France"], include_topics=False)
# -> choose variable_dcid from variables list where "France" appears in places_with_data
get_observations(variable_dcid=<chosen_dcid>, place_dcid=<dcid_for_France>, date="latest")
```

### 3.2 Rank Child Places of a Country

```bash
search_indicators(query="unemployment rate", places=["USA", "California, USA", "Texas, USA", "Florida, USA", "New York State, USA", "Illinois, USA"], include_topics=False)
# Determine common child place type from dcid_place_type_mappings (e.g., "State")
get_observations(variable_dcid=<rate_dcid>, place_dcid=<dcid_USA>, child_place_type="State", date="latest")
```

### 3.3 Bilateral Trade Query

```bash
search_indicators(query="trade exports", places=["France"], maybe_bilateral=True, include_topics=False)
# variable names may encode destination (France); choose one covering desired exporter
get_observations(variable_dcid=<exports_to_France_dcid>, place_dcid=<dcid_USA>, date="range", date_range_start="2020", date_range_end="2024")
```

### 3.4 Map of Country-Level GDP

```bash
search_indicators(query="GDP", places=["World", "USA", "China", "Germany", "Nigeria", "Brazil"], include_topics=False)
# pick GDP variable covering sampled countries
get_datacommons_chart_config(chart_type="map", chart_title="GDP by Country", variable_dcids=[<gdp_var>], parent_place_dcid=<dcid_World>, child_place_type="Country")
```

### 3.5 Multi-Variable Line Chart for One Place

```bash
search_indicators(query="population", places=["Canada"], include_topics=False)
search_indicators(query="median age", places=["Canada"], include_topics=False)
# collect variable_dcids
get_datacommons_chart_config(chart_type="line", chart_title="Population vs Median Age (Canada)", variable_dcids=[<pop_var>, <median_age_var>], place_dcids=[<dcid_Canada>])
```

## 4. Operational Rules for Agents

- Qualify place names ("California, USA" not "California").
- Sample before using child_place_type; never assume type.
- Avoid `date="all"` with child place mode; use `latest` or a bounded range.
- Set `per_search_limit` only when user explicitly asks.
- Treat search results as candidates; perform post-filtering/ranking if multiple matches.
- For bilateral: interpret `places_with_data` to decide correct `place_dcid` for observation calls.

## 5. Error Handling Strategies

| Scenario | Error Type | Resolution |
|----------|------------|-----------|
| Malformed date string | InvalidDateFormatError | Correct to YYYY or YYYY-MM or YYYY-MM-DD |
| `range` without bounds | InvalidDateRangeError | Supply at least one bound |
| No data for variable/place combo | DataLookupError | Re-run search with broader place sampling |
| Excessive unbounded child request | DataLookupError | Switch to `latest` or add range |

## 6. Performance Considerations

- Reuse variable DCIDs across related queries; cache prevents redundant lookups.
- Prefer hierarchy spec in chart configs instead of enumerating many place DCIDs.
- Limit child sampling to 5–6; larger sets add little discovery value.

## 7. Extensibility Notes

Add new tools by placing thin `@mcp.tool()` wrappers in `server.py` delegating to service-layer logic in `services.py`. Follow existing data model patterns for new request/response schemas. Update `USAGE.md` with new recipes and `CHANGELOG.md` with versioned entry.

## 8. CLI / Server Startup

```bash
# HTTP (streamable)
uvx datacommons-mcp serve http --port 8080
# stdio
uvx datacommons-mcp serve stdio
```

Ensure `DC_API_KEY` is exported; add `CUSTOM_DC_URL` for custom instances.

### 8.0 PowerShell Helper Script

On Windows (or PowerShell Core), prefer the helper script which creates the
venv if missing, performs an editable install, loads `.env`, and can run in
foreground or background:

```powershell
./scripts/start-server.ps1 -Mode http -Port 8080
./scripts/start-server.ps1 -Mode stdio
./scripts/start-server.ps1 -Mode http -Activate  # activates venv in current shell
./scripts/start-server.ps1 -Mode http -SkipApiKeyValidation  # bypass API key check
```

Background mode example with logging:

```powershell
./scripts/start-server.ps1 -Mode http -Background -LogFile server.log
Get-Content server.log -Tail 40
```

### 8.0.1 Persistence Change (FastMCP >= 2.12)

The server now runs HTTP via `uvicorn.run(mcp.http_app)` instead of the previous
`mcp.run(streamable-http)` to avoid early shutdown behavior observed with
newer FastMCP releases. Stdio mode still uses `mcp.run(transport="stdio")`.

### 8.0.2 Manual Tool Registration

Tools are registered manually (`mcp.tool()(fn)`) after definition in `server.py`
instead of using decorators directly. This preserves the original async
function objects so tests and agents can call them without `FunctionTool`
wrapping side-effects and simplifies monkeypatching.

### 8.0.3 Test Fixture Dependency

API key validation tests rely on the `requests_mock` fixture provided by the
`requests-mock` package. It is now pinned in `pyproject.toml`. If you run the
suite in a fresh environment ensure dependencies are installed so the fixture
is available.

### 8.1 VS Code Integration

This repository includes `.vscode/tasks.json` and `.vscode/launch.json` to streamline running and debugging the MCP server.

Steps:

1. Copy `.env.example` to `.env` (or export in your shell) and set `DC_API_KEY`.
2. In PowerShell (temporary session):

```powershell
$env:DC_API_KEY="<your_key>"
```

1. Run a task (Ctrl+Shift+P → "Run Task" → "Serve MCP (HTTP)" or "Serve MCP (stdio)").
1. For debugging, use the "Debug MCP Server (HTTP)" launch config (ensure the Python debugger extension is installed; update type to `debugpy` if prompted).
1. Health check:

```powershell
curl http://localhost:8080/health
```

1. Minimal tool call (HTTP example) using a quick Python snippet:

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

1. Stdio agent test: run the sample agent in `packages/datacommons-mcp/examples/sample_agents/basic_agent/agent.py` after setting `DC_API_KEY`:

```powershell
uv run python packages/datacommons-mcp/examples/sample_agents/basic_agent/agent.py
```

1. Stop server: Ctrl+C in its terminal.

If `DC_API_KEY` is invalid, startup will fail unless you pass `--skip-api-key-validation` on the serve command.

### 8.2 Container / Devcontainer Usage

If you develop inside a VS Code dev container (recommended for a clean host):

1. Open Command Palette → "Dev Containers: Reopen in Container" (after adding `.devcontainer/` files).
1. Set your API key inside the container shell:

```bash
export DC_API_KEY="<your_key>"
```

1. Run fallback tasks if `uvx` is not present:

```bash
python -m datacommons_mcp.cli serve http --port 8080
# or
python -m datacommons_mcp.cli serve stdio
```

1. Install uv optionally (already done in devcontainer build):

```bash
pip install uv
uv pip install -e .[test]
```

1. Switch tasks to the uvx variant once `uvx` exists in PATH:

```bash
uvx datacommons-mcp serve http --port 8080
```

1. Health check and tool invocation remain identical.

If you see `uvx: The term 'uvx' is not recognized`, it means uv was not installed in the current environment or PATH not refreshed—use the python -m fallback above.

## 9. Related Files

- `packages/datacommons-mcp/datacommons_mcp/services.py` – validation & processing
- `packages/datacommons-mcp/datacommons_mcp/clients.py` – API orchestration & caching
- `packages/datacommons-mcp/datacommons_mcp/topics.py` – topic store loading
- `packages/datacommons-mcp/datacommons_mcp/data_models/*` – typed schemas

## 10. Attribution

Copyright 2025 Google LLC. Licensed under Apache 2.0.

## 11. Troubleshooting (Common Pitfalls)

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `ModuleNotFoundError: No module named 'datacommons_mcp'` | Using system Python instead of project venv | Activate venv: `./.venv/Scripts/Activate.ps1` (PowerShell) or call `./.venv/Scripts/python.exe -m datacommons_mcp.cli ...` |
| Stray `PY` printed / command ignored | Attempted Bash heredoc (`python - <<'PY'`) in PowerShell | Use `python -c "..."`, temp file, or here-string piped to `Set-Content` |
| Server starts but `/health` 404 or connection refused | Wrong interpreter / import failure before uvicorn binds | Re-run inside venv; check logs for early exception |
| Background logs missing stderr | PowerShell cannot redirect stdout & stderr to same file | Use helper script `start-server.ps1 -Background -LogFile server.log` (stderr auto-split) |
| Child place request with `date="all"` fails | Data volume guard | Switch to `date="latest"` or bounded `range` |
| Ambiguous place results (e.g., wrong "Springfield") | Unqualified place name | Qualify: `Springfield, IL, USA` |
| Variable not found for hierarchy | Skipped child sampling | Include parent + 5–6 diverse children in `search_indicators` |
| Tool enumeration error (`await` missing) | Forgot async get_tools usage | Use `asyncio.run(mcp.get_tools())` in diagnostics |

### Quick Diagnostic Script (PowerShell)

```powershell
./scripts/preflight.ps1 -Verbose
```

Runs: venv check, editable install presence, core imports, API key existence, and prints actionable messages before you start the server.

### Minimal Health Check

```powershell
curl http://localhost:8080/health
```

Should return `OK`. If not, verify interpreter path and API key handling.
