# Compile and run the self-checking Chiplet Interconnect testbench.
# Usage: powershell -ExecutionPolicy Bypass -File .\run_tb.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$iverilog = "D:\PY_AI\iverilog\bin\iverilog.exe"
$vvp      = "D:\PY_AI\iverilog\bin\vvp.exe"

if (-not (Test-Path $iverilog)) { throw "iverilog not found at $iverilog" }
if (-not (Test-Path $vvp))      { throw "vvp not found at $vvp" }

New-Item -ItemType Directory -Force -Path "$root\build" | Out-Null

$rtl = @(
    "rtl\core.v",
    "rtl\packet_generator.v",
    "rtl\tx.v",
    "rtl\fault_injector.v",
    "rtl\multi_lane_link.v",
    "rtl\rx.v",
    "rtl\packet_checker.v",
    "rtl\link_controller.v",
    "rtl\error_monitor.v"
) | ForEach-Object { Join-Path $root $_ }

& $iverilog -g2012 -Wno-timescale -o "$root\build\tb_chiplet.vvp" "$root\tb\tb_chiplet.v" @rtl
if ($LASTEXITCODE -ne 0) { throw "iverilog compile failed" }

& $vvp "$root\build\tb_chiplet.vvp"
if ($LASTEXITCODE -ne 0) { throw "simulation failed" }
