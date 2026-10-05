# Lite path for Windows PowerShell: pure Python, in-process Qdrant, SQLite Feast online store.
# No Docker, no external services. ~60s on a clean machine.

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "[lite] Day 19 lightweight setup (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "[lite] Stack: fastembed + qdrant-client[memory] + rank-bm25 + feast(sqlite) + FastAPI" -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

# ── 1. Python Check ────────────────────────────────────────────────────────
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pyCmd) {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if (-not $pyCmd) {
        Write-Error "[lite] Python not found. Please install Python 3.10+ and add it to PATH."
        exit 1
    }
    $PYTHON = "py"
} else {
    $PYTHON = "python"
}

$PY_VER = & $PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
Write-Host "[lite] System Python is $PY_VER"

# ── 2. Create venv ─────────────────────────────────────────────────────────
if (-not (Test-Path ".venv")) {
    Write-Host "[lite] Creating venv with $PYTHON -m venv .venv"
    & $PYTHON -m venv .venv
} else {
    Write-Host "[lite] Existing .venv detected."
}

$VENV_PY = ".\.venv\Scripts\python.exe"
$VENV_PIP = ".\.venv\Scripts\pip.exe"
$VENV_JUPYTEXT = ".\.venv\Scripts\jupytext.exe"

# ── 3. Install deps ────────────────────────────────────────────────────────
Write-Host "[lite] Upgrading pip in venv..."
& $VENV_PY -m pip install -q -U pip

$NEED_DILL_OVERRIDE = & $VENV_PY -c 'import sys; print(1 if sys.version_info >= (3,14) else 0)'
Write-Host "[lite] Installing dependencies from requirements.txt..."

if ($NEED_DILL_OVERRIDE -eq "1") {
    Write-Host "[lite] Python >= 3.14 detected -> installing requirements with dill override"
    & $VENV_PIP install -q -r requirements.txt
    & $VENV_PIP install -q --upgrade 'dill>=0.4,<1.0'
} else {
    & $VENV_PIP install -q -r requirements.txt
}

# ── 4. Convert Jupytext sources to .ipynb ──────────────────────────────────
Write-Host "[lite] Converting Jupytext notebooks to .ipynb..."
Get-ChildItem -Path "notebooks" -Filter "[0-9]*.py" | ForEach-Object {
    & $VENV_JUPYTEXT --to notebook $_.FullName
}

# ── 5. .env scaffold ───────────────────────────────────────────────────────
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "[lite] Copied .env.example -> .env"
}

# ── 6. Seed corpus + golden set + advanced missions ───────────────────────
Write-Host "[lite] Seeding corpus + golden set..."
& $VENV_PY scripts/seed_corpus.py

Write-Host "[lite] Seeding advanced-mission data (NB6 + NB8)..."
& $VENV_PY scripts/gen_agent_queries.py
& $VENV_PY scripts/gen_spend.py

# ── 7. Smoke test ──────────────────────────────────────────────────────────
Write-Host "`n[lite] Running smoke test scripts/verify_lite.py..." -ForegroundColor Yellow
& $VENV_PY scripts/verify_lite.py

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "[lite] Setup completed successfully!" -ForegroundColor Green
Write-Host "To activate the environment in PowerShell:" -ForegroundColor Green
Write-Host "    .\.venv\Scripts\Activate.ps1"
Write-Host "`nEquivalent commands for Windows:" -ForegroundColor Cyan
Write-Host "  - Start FastAPI:    uvicorn app.main:app --reload --port 8000"
Write-Host "  - Start JupyterLab: jupyter lab --notebook-dir=notebooks --ServerApp.token='' --no-browser"
Write-Host "  - Run benchmark:    python scripts/benchmark.py"
Write-Host "  - Run pytest:       pytest -q"
Write-Host "====================================================" -ForegroundColor Green
