"""Debug runner for HTTP serving issues.

Run with: python -m datacommons_mcp.debug_http --port 8080 --host localhost
Provides verbose diagnostics about FastMCP internals and attempts to
start a uvicorn server directly using the constructed http_app.
"""

from __future__ import annotations

import argparse
import inspect
import sys
import uvicorn

from datacommons_mcp.server import mcp


def main() -> None:  # pragma: no cover - manual debug script
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    print("[debug] FastMCP name:", mcp.name)
    print("[debug] Tools registered:", [t.name for t in getattr(mcp, "_tools", [])])
    print("[debug] FastMCP.run signature:")
    print(inspect.signature(mcp.run))
    print("[debug] FastMCP.run_http_async source (first 30 lines):")
    src = inspect.getsource(type(mcp).run_http_async).splitlines()
    for line in src[:30]:
        print("   ", line)

    print("[debug] Building http_app (transport=http, stateless_http=False)...")
    app = mcp.http_app(transport="http", stateless_http=False)
    print("[debug] App state path:", getattr(getattr(app, "state", None), "path", None))

    print("[debug] Starting uvicorn directly...")
    try:
        uvicorn.run(app, host=args.host, port=args.port, log_level="debug")
    except Exception as e:  # pragma: no cover
        print("[debug] Exception starting uvicorn:", e)
        sys.exit(1)
    print("[debug] uvicorn.run returned (server stopped)")


if __name__ == "__main__":  # pragma: no cover
    main()
