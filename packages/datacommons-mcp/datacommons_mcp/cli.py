import asyncio
import logging
import os
import sys

import click
import uvicorn
from click.core import Context, Option, ParameterSource

from .exceptions import APIKeyValidationError, InvalidAPIKeyError
from .utils import validate_api_key
from .version import __version__

# A map of server modes to the set of option names applicable to that mode.
MODE_SPECIFIC_OPTIONS: dict[str, set[str]] = {
    "http": {"host", "port"},
    "stdio": set(),
}

# Options that are common to all modes.
COMMON_OPTIONS: set[str] = {"skip_api_key_validation"}


@click.group()
@click.version_option(version=__version__)
def cli() -> None:
    """DataCommons MCP CLI - Model Context Protocol server for Data Commons."""
    logging.basicConfig(level=logging.INFO)


def _validate_mode_options(ctx: Context, mode: str) -> None:
    """Checks for options that are not applicable to the selected mode."""
    provided_options = {
        param.name
        for param in ctx.command.params
        if isinstance(param, Option)
        and ctx.get_parameter_source(param.name) is not ParameterSource.DEFAULT
    }
    allowed_options = COMMON_OPTIONS.union(MODE_SPECIFIC_OPTIONS.get(mode, set()))
    invalidly_used_options = provided_options - allowed_options

    if invalidly_used_options:
        # Format a user-friendly error message.
        opts_str = ", ".join(f"--{opt}" for opt in sorted(invalidly_used_options))
        raise click.UsageError(
            f"The following option(s) are not applicable in '{mode}' mode: {opts_str}"
        )


def _run_api_key_validation(ctx: Context, *, skip_validation: bool) -> None:
    """Runs the API key validation unless skipped."""
    if skip_validation:
        click.echo("Skipping API key validation as requested.", err=True)
        return

    try:
        api_key = os.getenv("DC_API_KEY")
        if not api_key:
            raise InvalidAPIKeyError("DC_API_KEY is not set.")
        validate_api_key(api_key)
    except (InvalidAPIKeyError, APIKeyValidationError) as e:
        click.echo(str(e), err=True)
        click.echo(
            "To obtain an API key, go to https://apikeys.datacommons.org and "
            "request a key for the api.datacommons.org domain.",
            err=True,
        )
        sys.stderr.flush()
        ctx.exit(1)


def _run_http_server(host: str, port: int) -> None:
    """Starts the server in HTTP mode (persistent)."""
    from datacommons_mcp.server import mcp

    click.echo("Starting DataCommons MCP server (uvicorn http)")
    click.echo(f"Version: {__version__}")
    click.echo(f"Health: http://{host}:{port}/health")
    click.echo(f"MCP: http://{host}:{port}/mcp")
    click.echo("Press CTRL+C to stop")
    names = "unavailable"
    if hasattr(mcp, "get_tools"):
        try:
            tools = asyncio.run(mcp.get_tools())  # type: ignore[arg-type]
            names = ", ".join(t.name for t in tools)
        except Exception as e:  # noqa: BLE001
            names = f"error: {e}"
    click.echo(f"[diag] tools: {names}")
    click.echo("[diag] starting uvicorn")
    uvicorn.run(mcp.http_app, host=host, port=port, log_level="info")


def _run_stdio_server() -> None:
    """Starts the server in stdio mode."""
    from datacommons_mcp.server import mcp

    click.echo("Starting DataCommons MCP server in stdio mode", err=True)
    click.echo(f"Version: {__version__}", err=True)
    click.echo("Ready for stdin/stdout requests", err=True)
    click.echo("[diag] Entering mcp.run() (stdio)", err=True)
    mcp.run(transport="stdio")
    click.echo("[diag] mcp.run() returned (stdio) - stdin closed", err=True)


@cli.command()
@click.argument("mode", type=click.Choice(["http", "stdio"]))
@click.option(
    "--skip-api-key-validation",
    is_flag=True,
    default=False,
    help="Skip the validation of the DC_API_KEY at startup.",
)
@click.option("--host", default="localhost", help="Host (http mode only).")
@click.option("--port", default=8080, help="Port (http mode only).", type=int)
@click.pass_context
def serve(
    ctx: click.Context,
    *,
    mode: str,
    skip_api_key_validation: bool,
    host: str,
    port: int,
) -> None:
    """Serve the MCP server in different modes."""
    _validate_mode_options(ctx, mode)
    _run_api_key_validation(ctx, skip_validation=skip_api_key_validation)

    try:
        if mode == "http":
            _run_http_server(host, port)
        elif mode == "stdio":
            _run_stdio_server()
    except ImportError as e:
        click.echo(f"Error starting server: {e}", err=True)
        sys.exit(1)


def main() -> None:
    """Main entry point for the CLI."""
    cli()
