import pytest

@pytest.mark.asyncio
async def test_tools_registered():
    from datacommons_mcp.server import mcp
    assert hasattr(mcp, "get_tools"), "FastMCP missing get_tools method"
    raw = await mcp.get_tools()  # type: ignore[arg-type]
    # get_tools may return list of Tool objects or names depending on fastmcp version
    names = []
    for item in raw:
        if hasattr(item, "name"):
            names.append(item.name)  # type: ignore[attr-defined]
        elif isinstance(item, str):
            names.append(item)
    names = sorted(names)
    # Expect the two core tools
    assert "get_observations" in names, f"get_observations missing in {names}"
    assert "search_indicators" in names, f"search_indicators missing in {names}"
    # No duplicates
    assert len(names) == len(set(names)), "Duplicate tool names detected"
