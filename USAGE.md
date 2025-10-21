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

## 9. Related Files

- `packages/datacommons-mcp/datacommons_mcp/services.py` – validation & processing
- `packages/datacommons-mcp/datacommons_mcp/clients.py` – API orchestration & caching
- `packages/datacommons-mcp/datacommons_mcp/topics.py` – topic store loading
- `packages/datacommons-mcp/datacommons_mcp/data_models/*` – typed schemas

## 10. Attribution

Copyright 2025 Google LLC. Licensed under Apache 2.0.
