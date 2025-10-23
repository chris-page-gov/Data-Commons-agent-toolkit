"""Basic integration tests for MCP tool wrappers.

The service layer functions are monkeypatched to avoid network access while
verifying that the server-level tool functions return properly shaped models.
"""

from __future__ import annotations

import pytest

from datacommons_mcp import services
from datacommons_mcp.server import get_observations, search_indicators
from datacommons_mcp.data_models.observations import (
    ObservationToolResponse,
    Node,
    FacetMetadata,
    PlaceObservation,
)
from datacommons_mcp.data_models.search import SearchResponse, SearchVariable


class _DummySourceMeta(FacetMetadata):
    """Minimal facet metadata stub used in tests."""

    source_id: str


@pytest.mark.asyncio
async def test_search_indicators_minimal(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Patched search_indicators returns a minimal SearchResponse."""

    async def fake_search(
        _client: object, **_kwargs: object
    ) -> SearchResponse:  # noqa: ARG001
        variable = SearchVariable(
            dcid="dc/v/Population_Count", places_with_data=["country/FRA"]
        )
        return SearchResponse(
            topics=[],
            variables=[variable],
            dcid_name_mappings={
                "dc/v/Population_Count": "Population",
                "country/FRA": "France",
            },
            dcid_place_type_mappings={"country/FRA": ["Country"]},
            status="SUCCESS",
        )

    monkeypatch.setattr(services, "search_indicators", fake_search)

    resp = await search_indicators(
        query="population", places=["France"], include_topics=False
    )

    assert resp.status == "SUCCESS"
    assert resp.variables[0].dcid == "dc/v/Population_Count"
    assert resp.variables[0].places_with_data == ["country/FRA"]


@pytest.mark.asyncio
async def test_get_observations_minimal(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Patched get_observations returns a minimal ObservationToolResponse."""

    async def fake_obs(
        _client: object, **_kwargs: object
    ) -> ObservationToolResponse:  # noqa: ARG001
        return ObservationToolResponse(
            variable=Node(dcid="dc/v/Population_Count", name="Population"),
            place_observations=[
                PlaceObservation(
                    place=Node(dcid="country/FRA", name="France"),
                    time_series=[("2024-01-01", 68000000.0)],
                )
            ],
            source_metadata=_DummySourceMeta(source_id="source/WorldBank"),
            alternative_sources=[],
        )

    monkeypatch.setattr(services, "get_observations", fake_obs)

    resp = await get_observations(
        variable_dcid="dc/v/Population_Count",
        place_dcid="country/FRA",
        date="latest",
    )

    assert resp.variable.dcid == "dc/v/Population_Count"
    assert resp.place_observations[0].place.dcid == "country/FRA"
    assert resp.place_observations[0].time_series[0][1] == 68000000.0
