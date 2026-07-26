# Chronicle setup for Windows (requires opam + OCaml 5.x)
$ErrorActionPreference = "Stop"

if (-not (Get-Command opam -ErrorAction SilentlyContinue)) {
    Write-Host "opam not found. Install with:"
    Write-Host "  winget install OCaml.opam"
    Write-Host "  winget install Diskuv.OCaml"
    Write-Host "Then restart your shell and re-run this script."
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Installing opam dependencies..."
opam install . --deps-only --with-test --yes

Write-Host "Building..."
opam exec -- dune build

Write-Host "Running tests..."
opam exec -- dune runtest

Write-Host "Chronicle ready. Try:"
Write-Host "  opam exec -- dune exec chronicle -- doctor"
Write-Host "  opam exec -- dune exec chronicle -- run --domain elevator examples/elevator/scenarios/up_down.sexp"
