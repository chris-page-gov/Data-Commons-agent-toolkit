<#
Start the Data Commons MCP server with automatic venv handling.
Usage:
  ./scripts/start-server.ps1 -Mode http -Port 8080
Parameters:
  -Mode  http|stdio (default http)
  -Port  Port number when Mode=http (default 8080)
  -SkipApiKeyValidation Switch to pass --skip-api-key-validation
  -Activate  Optional; if set, dot-source venv Activate.ps1 so your shell uses venv.
  -Background  Optional; start server in background (non-blocking). HTTP mode recommended.
  -BindHost  Optional; host to bind (http mode) default 'localhost'
  -LogFile Optional; path to capture stdout/stderr
Environment:
  Requires DC_API_KEY unless SkipApiKeyValidation specified.
#>
param(
  [ValidateSet('http','stdio')] [string]$Mode = 'http',
  [int]$Port = 8080,
  [switch]$SkipApiKeyValidation,
  [switch]$Activate,
  [switch]$Background,
  [string]$BindHost = 'localhost',
  [string]$LogFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $repoRoot '.venv'
$pythonExe = Join-Path $venvPath 'Scripts/python.exe'

function Ensure-Venv {
  if (-not (Test-Path $pythonExe)) {
    Write-Host '[setup] Creating venv (Python 3.12 launcher required)...'
    py -3.12 -m venv $venvPath
  }
}

function Ensure-PackageInstalled {
  $code = "import importlib,sys; print('python', sys.version);\ntry: importlib.import_module('datacommons_mcp'); print('OK');\nexcept Exception as e: print('MISS', e)";
  $result = & $pythonExe -c $code 2>&1
  if ($result -match 'MISS') {
    Write-Host '[setup] Installing datacommons-mcp (editable)...'
    & $pythonExe -m pip install --upgrade pip | Out-Null
    & $pythonExe -m pip install -e (Join-Path $repoRoot 'packages/datacommons-mcp') | Out-Null
  }
}

# Additional dependency + import diagnostics (fastmcp, fastapi, uvicorn)
function Test-CoreImports {
  $diag = @'
import importlib, traceback
modules = ["fastmcp", "fastapi", "uvicorn", "datacommons_mcp.server"]
results = []
for m in modules:
    try:
        mod = importlib.import_module(m)
        results.append(f"IMPORT_OK {m} -> {getattr(mod,'__file__', 'builtin')}")
    except Exception as e:
        results.append(f"IMPORT_FAIL {m} {e}")
print("|".join(results))
'@
  try {
    $out = & $pythonExe -c $diag 2>&1
    Write-Host "[diag] $out"
  } catch {
    Write-Warning "[diag] Unexpected error running import diagnostics: $_"
  }
}

Test-CoreImports

Ensure-Venv
Ensure-PackageInstalled

# Load .env file if present (simple KEY=VALUE parser, ignores comments)
$envFile = Join-Path $repoRoot '.env'
if (Test-Path $envFile) {
  Write-Host "[env] Loading environment variables from .env"
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    if ($line.StartsWith('#')) { return }
    $parts = $line -split '=',2
    if ($parts.Count -eq 2) {
      $key = $parts[0].Trim()
      $val = $parts[1].Trim().Trim('"')
      if ($key) {
        Set-Item -Path Env:$key -Value $val
      }
    }
  }
}

if (-not $SkipApiKeyValidation) {
  if (-not $env:DC_API_KEY) {
    Write-Error 'DC_API_KEY not set. Export it or use -SkipApiKeyValidation.'
    exit 1
  }
}

$serveArgs = @('datacommons_mcp.cli','serve',$Mode)
if ($Mode -eq 'http') { $serveArgs += @('--host',$BindHost,'--port',$Port) }
if ($SkipApiKeyValidation) { $serveArgs += '--skip-api-key-validation' }

if ($Activate) {
  $activateScript = Join-Path $venvPath 'Scripts/Activate.ps1'
  if (Test-Path $activateScript) {
    Write-Host '[venv] Activating venv in current shell.'
    . $activateScript
  } else {
    Write-Warning 'Activate.ps1 not found; continuing without activation.'
  }
}

if ($Background) {
  if ($Mode -eq 'stdio') {
    Write-Warning 'Background stdio mode offers no interactive channel; consider http mode instead.'
  }
  Write-Host "[bg] Launching background server (mode=$Mode host=$BindHost port=$Port)" -ForegroundColor Green
  # Use unbuffered (-u) to force immediate stdout/stderr flush and include module (-m)
  $argList = @('-u','-m') + $serveArgs
  # Emit quick env diagnostics prior to launch
  Write-Host "[bg] PYTHONUNBUFFERED will be active (-u flag)." -ForegroundColor DarkGray
  if ($env:DC_API_KEY) {
    Write-Host "[bg] DC_API_KEY length: $($env:DC_API_KEY.Length)" -ForegroundColor DarkGray
  } else {
    Write-Host "[bg] DC_API_KEY not present in environment prior to launch." -ForegroundColor Yellow
  }
  if ($LogFile) {
    # PowerShell Start-Process cannot redirect stdout & stderr to the SAME file path.
    # Use separate files and inform the user; keep requested path as stdout target.
    $stdoutFile = $LogFile
    $stderrFile = if ($LogFile.Contains('.')) { $LogFile -replace '\.[^\.]+$', '.err.log' } else { "$LogFile.err" }
  $proc = Start-Process -FilePath $pythonExe -ArgumentList $argList -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    Write-Host "[bg] Logging -> stdout: $stdoutFile | stderr: $stderrFile"
  } else {
  $proc = Start-Process -FilePath $pythonExe -ArgumentList $argList -PassThru -NoNewWindow
  }
  Write-Host "[bg] PID=$($proc.Id). To stop: Stop-Process -Id $($proc.Id)"
  if ($Mode -eq 'http') {
    Write-Host '[bg] Polling health endpoint...'
  $healthUrl = "http://$($BindHost):$Port/health"
    $maxAttempts = 15
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
      Start-Sleep -Milliseconds 400
      try {
        $resp = Invoke-WebRequest -Uri $healthUrl -Method GET -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
          Write-Host "[bg] Health OK ($healthUrl)" -ForegroundColor Green
          break
        }
      } catch {
        # swallow until max attempts
      }
      $attempt++
    }
    if ($attempt -ge $maxAttempts) {
      Write-Warning "[bg] Health check failed after $maxAttempts attempts; verify logs (PID=$($proc.Id))."
      if ($LogFile) { Write-Host "[bg] View log tail: Get-Content -Path $LogFile -Tail 40" }
    }
  }
} else {
  Write-Host "[run] Starting server (mode=$Mode host=$BindHost port=$Port)" -ForegroundColor Green
  Write-Host "[run] Using Python: $pythonExe"
  if ($Activate) { Write-Host "[run] VIRTUAL_ENV=$env:VIRTUAL_ENV" }
  Write-Host '[run] Press Ctrl+C to stop.'
  if ($LogFile) {
    Write-Host "[run] Logging -> $LogFile"
  # Wrap server start in inline Python (-c) to capture traceback explicitly
  $argJson = ($serveArgs | ConvertTo-Json -Compress)
  $py = @'
import json, runpy, sys, traceback
serve_args = json.loads(sys.argv[1])
sys.argv = serve_args[:]  # mimic real argv
try:
  runpy.run_module('datacommons_mcp.cli', run_name='__main__')
except SystemExit:
  raise
except Exception:
  print('SERVER_EXCEPTION_START')
  traceback.print_exc()
  print('SERVER_EXCEPTION_END')
  sys.exit(1)
'@
  & $pythonExe -c $py $argJson *>&1 | Tee-Object -FilePath $LogFile
  } else {
  & $pythonExe -m $serveArgs
  }
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) { Write-Warning "[run] Server exited with code $exitCode" }
}
