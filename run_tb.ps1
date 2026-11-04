# Compile and run the self-checking chiplet testbench with Icarus Verilog.
# Usage (from D:\VERILOG):  powershell -ExecutionPolicy Bypass -File .\run_tb.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$iverilog = "D:\PY_AI\iverilog\bin\iverilog.exe"
$vvp      = "D:\PY_AI\iverilog\bin\vvp.exe"

if (-not (Test-Path $iverilog)) { throw "iverilog not found at $iverilog" }
if (-not (Test-Path $vvp))      { throw "vvp not found at $vvp" }

New-Item -ItemType Directory -Force -Path "$root\build" | Out-Null

$rtl = @(
    "core.v",
    "packet_generator.v",
    "tx.v",
    "fault_injector.v",
    "multi_lane_link.v",
    "rx.v",
    "packet_checker.v",
    "link_controller.v",
    "error_monitor.v"
)

& $iverilog -g2012 -Wno-timescale -o "$root\build\tb_chiplet.vvp" "$root\tb_chiplet.v" ($rtl | ForEach-Object { Join-Path $root $_ })
if ($LASTEXITCODE -ne 0) { throw "iverilog compile failed" }

& $vvp "$root\build\tb_chiplet.vvp"
if ($LASTEXITCODE -ne 0) { throw "simulation failed" }
