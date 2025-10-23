# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project (once stable) will follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial `USAGE.md` documenting advanced MCP usage patterns (validation workflow, source ranking, caching, bilateral handling, chart config factory).
- Project-specific AI agent guidance in `.github/copilot-instructions.md`.

### Changed

- (none)

### Fixed

- (none)

## [1.1.0rc2] - 2025-10-23

### 1.1.0rc2 Added

- Async tool enumeration test (`test_tools_registration.py`) ensuring FastMCP registration viability.
- Added `requests-mock` test dependency to support `requests_mock` fixture (API key validation tests).

### 1.1.0rc2 Changed

- Pinned core runtime dependencies in `pyproject.toml` (fastapi, uvicorn, fastmcp, requests, datacommons-client, pydantic, pydantic-settings, python-dateutil) for reproducible builds.
- HTTP serving refactored: use `uvicorn.run(mcp.http_app)` instead of `mcp.run(streamable-http)` due to FastMCP lifecycle changes.
- Manual tool registration retained (avoid decorator symbol replacement) to keep direct function callability in tests; agent instruction docs updated to emphasize search→observe workflow and child place sampling rules.

### 1.1.0rc2 Fixed

- Eliminated premature server exit under FastMCP 2.12+ by switching to explicit uvicorn run.

## [1.1.0rc1] - 2025-10-21

### 1.1.0rc1 Added

- Release candidate for 1.1.0 of `datacommons-mcp` Python package.
- Expanded tool docstrings (`get_observations`, `search_indicators`) describing bilateral data and sampling strategies.

### 1.1.0rc1 Changed

- Updated internal validation around chart configuration location determination.

### 1.1.0rc1 Fixed

- Minor logging improvements for settings load failures.

## [1.0.0] - 2025-xx-xx

### 1.0.0 Added

- Baseline MCP server with tools: `search_indicators`, `get_observations`.
- Topic store loading and variable existence caching.
- Source selection algorithm and date filtering semantics.

[Unreleased]: https://github.com/chris-page-gov/Data-Commons-agent-toolkit/compare/main...crpage
[1.1.0rc2]: https://github.com/chris-page-gov/Data-Commons-agent-toolkit/compare/1.1.0rc1...1.1.0rc2
[1.1.0rc1]: https://github.com/chris-page-gov/Data-Commons-agent-toolkit/compare/1.0.0...1.1.0rc1

## [1.1.0rc3] - 2025-10-23

### 1.1.0rc3 Added

- Troubleshooting section in `USAGE.md` (common pitfalls: venv activation, PowerShell heredoc misuse, log redirection, health diagnostics).
- Preflight diagnostics script `scripts/preflight.ps1` (checks venv, editable install, core imports, API key presence).
- Environment & shell safety guidance added to agent instruction files and `.github/copilot-instructions.md`.

### 1.1.0rc3 Changed

- Minor documentation expansions to reinforce search→observe workflow and prevent repeated startup mistakes.

### 1.1.0rc3 Fixed

- Clarified Windows PowerShell vs Bash invocation patterns to prevent stray `PY` artifacts and module import failures.

[1.1.0rc3]: https://github.com/chris-page-gov/Data-Commons-agent-toolkit/compare/1.1.0rc2...1.1.0rc3
