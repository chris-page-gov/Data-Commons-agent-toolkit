<#
Preflight diagnostics for Data Commons MCP server.
Checks venv, editable install, core imports, and API key prior to startup.
Usage:
  ./scripts/preflight.ps1 [-Verbose]
#>
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $repoRoot '.venv'
$pythonExe = Join-Path $venvPath 'Scripts/python.exe'

function Write-Status([string]$Label, [string]$Status, [ConsoleColor]$Color = 'Gray') {
  Write-Host ("[{0}] {1}" -f $Label, $Status) -ForegroundColor $Color
}

# 1. Venv presence
if (Test-Path $pythonExe) {
  Write-Status 'venv' "FOUND ($pythonExe)" Green
} else {
  Write-Status 'venv' 'MISSING - create with: py -3.12 -m venv .venv' Red
  return
}

# 2. Editable install presence
$code = "import importlib, sys; print('python', sys.version);\ntry: importlib.import_module('datacommons_mcp'); print('EDITABLE_OK');\nexcept Exception as e: print('EDITABLE_MISS', e)"
$out = & $pythonExe -c $code 2>&1
if ($out -match 'EDITABLE_OK') {
  Write-Status 'editable' 'datacommons_mcp import OK' Green
} else {
  Write-Status 'editable' 'MISSING - run: ./.venv/Scripts/python.exe -m pip install -e packages/datacommons-mcp' Yellow
}

# 3. Core imports
$diag = @'
import importlib
mods = ["fastmcp","fastapi","uvicorn","pydantic"]
for m in mods:
    try:
        mod = importlib.import_module(m)
        print(f"IMPORT_OK {m}")
    except Exception as e:
        print(f"IMPORT_FAIL {m} {e}")
'@
$core = & $pythonExe -c $diag 2>&1
$core.Split('|') | ForEach-Object { $_ } | ForEach-Object {
  if ($_ -match 'IMPORT_OK') { Write-Status 'import' $_ Green } elseif ($_){ Write-Status 'import' $_ Red }
}

# 4. API key presence
if ($env:DC_API_KEY) {
  Write-Status 'api_key' "SET (length=$($env:DC_API_KEY.Length))" Green
} else {
  Write-Status 'api_key' 'NOT SET - export DC_API_KEY or use --skip-api-key-validation' Yellow
}

# 5. Health endpoint hint
Write-Status 'next' 'Start server: ./.venv/Scripts/python.exe -m datacommons_mcp.cli serve http --port 8080' Cyan
Write-Status 'next' 'Health check: curl http://localhost:8080/health' Cyan

Write-Host 'Preflight complete.' -ForegroundColor Green
