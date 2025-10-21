# Data Commons Agent Toolkit – AI Coding Agent Instructions

Use these project-specific guidelines when writing code, tests, or docs. Keep changes minimal, follow existing patterns, and prefer improving clarity + correctness over introducing new abstractions.

## 1. Architecture Snapshot
- Core package: `packages/datacommons-mcp/datacommons_mcp/` implements an MCP server exposing Data Commons tools.
- Entry point: `server.py` builds a `FastMCP` instance and registers tools (`get_observations`, `search_indicators`). Business logic lives in `services.py`; server layer is thin.
- Client abstraction: `clients.py (DCClient)` wraps `datacommons_client` providing search + observation orchestration, caching (LRU for place variables), and topic store loading/merging.
- Settings: `data_models/settings.py` + `settings.py` resolve environment-based configuration (base vs custom DC). Factory `create_dc_client` chooses base/custom client.
- Topic graph: `topics.py` loads JSON caches in `data/topics/*` into a `TopicStore` (flattened member vs descendant variables) used for existence filtering and name resolution.
- Data models: Pydantic models under `data_models/` (observations, search, charts, settings) define strict schemas for tool I/O. Chart configs use discriminated unions + location models.
- Flow (search → observe): Always call `search_indicators` first to discover valid variable/place combinations; pass returned DCIDs into `get_observations`. Never invent DCIDs.

## 2. Critical Conventions & Patterns
- Validation first: Service `_validate_and_build_request` builds an `ObservationRequest`; all date normalization & place name resolution happens here. Do NOT bypass.
- Date semantics: `date` can be enum (`latest|all|range`) or a concrete partial date (`YYYY|YYYY-MM|YYYY-MM-DD`). If `date='range'`, supply at least one bound (`date_range_start`/`date_range_end`). Single concrete date becomes an interval with identical start/end.
- Child place mode: Only set `child_place_type` after sampling child places via `search_indicators` and ensuring a common type. If ambiguous, fall back to single place calls.
- Source selection: Primary source chosen by: places covered > observation count > latest date > average facet index (lower better) > source_id. Respect this logic; don’t re-rank externally.
- Place resolution: External calls should use human-readable qualified names ("California, USA"), never DCIDs. Resolution to DCID occurs inside services/client.
- Topics vs variables: When `include_topics=False`, topics are expanded to descendant variables; when `True`, topic membership (flattened for base) is preserved. Match existing expansion logic in `clients.py`.
- Chart config factory (`get_datacommons_chart_config`): Build location object (multi-place vs hierarchy vs single) based on provided args; enforce mutually exclusive place specs.
- Error handling: Raise domain-specific exceptions (`InvalidDateFormatError`, `InvalidDateRangeError`, `DataLookupError`) for validation; avoid generic Exception. Tests assert message substrings.
- Caching: Variable existence per place cached in `DCClient.variable_cache` (LRU 128). Populate before filtering. Don’t duplicate caching layers.

## 3. Testing Approach
- Framework: `pytest` with async tests using `pytest.mark.asyncio` and `AsyncMock` for client methods.
- Style: Tests assert both behavior and selection logic (e.g., primary source tie-breakers). Keep new tests consistent: arrange mock client → act → assert specific fields on Pydantic models.
- Error messages: Tests expect partial matches; preserve phrasing if modifying validation.

## 4. Adding / Modifying Functionality
- Extend tools: Prefer adding logic in `services.py` and keep `server.py` tool wrappers minimal. New tool = thin `@mcp.tool()` delegating to a service function.
- New models: Define in appropriate `data_models/*` module; use explicit Field descriptions; keep discriminated unions coherent.
- Settings: Add env vars by extending settings models (`BaseDCSettings` / `CustomDCSettings`). Update tests in `test_settings.py` to cover parsing.
- Search changes: Adjust `_fetch_indicators_new` or filtering helpers; ensure both legacy and new endpoint paths remain intact unless deprecated.

## 5. Common Pitfalls to Avoid
- Inventing DCIDs or child place types – always derive from search results (`dcid_place_type_mappings`).
- Requesting huge child-place ranges with `date='all'`—must constrain to `latest` or bounded range.
- Returning raw API responses – always transform into Pydantic tool response models.
- Mixing place_dcid and place_name simultaneously in requests—service layer chooses precedence; don’t change signature expectations.
- Breaking tie-breaker order for source selection; tests rely on deterministic sequence.

## 6. Dev Workflow
- Run tests (from repo root): use the project’s configured Python (uv recommended). Example:
  - `uv run pytest packages/datacommons-mcp/tests -q`
- Setting up env: export `DC_API_KEY` (required). For custom instances also set `CUSTOM_DC_URL` and optionally `DC_SEARCH_SCOPE`, `DC_ROOT_TOPIC_DCIDS`.
- Start server (HTTP): `uvx datacommons-mcp serve http --port 8080`  → health at `/health`.
- Start server (stdio): `uvx datacommons-mcp serve stdio`.

## 7. Code Style & Quality
- Preserve logging structure: use module-level `logger = logging.getLogger(__name__)`.
- Avoid broad except; catch specific exceptions where behavior differs (API/network vs validation).
- Keep token efficiency: tool response models exclude None values; don’t add verbose unused fields.
- Prefer small, single-responsibility helpers (see `_process_sources_and_filter_observations`).

## 8. When Unsure
Leverage existing patterns—mirror how `search_indicators` and `get_observations` coordinate validation, caching, transformation. Add clarifying docstrings where logic is complex; keep instructions concise.

---
If guidance seems incomplete (e.g., need adding a new chart type or endpoint deprecation path), surface a clarification request instead of guessing.
