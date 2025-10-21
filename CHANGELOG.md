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
[1.1.0rc1]: https://github.com/chris-page-gov/Data-Commons-agent-toolkit/compare/1.0.0...1.1.0rc1
