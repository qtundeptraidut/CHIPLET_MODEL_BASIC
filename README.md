# Chiplet Interconnect

A simple 2-lane chiplet interconnect model with deterministic packet generation, link training, fault injection and error monitoring.

## Layout

```text
rtl/    RTL source
tb/     Self-checking testbench
build/  Generated simulation artifacts (not tracked)
```

## Run the testbench

```powershell
powershell -ExecutionPolicy Bypass -File .\run_tb.ps1
```

## Notes

- `top.v` is the FPGA wrapper; for Cocotb, instantiate `chiplet_interconnect_core`.
- Fault injection is measured as packet/lane errors.
- Retraining is deliberately disabled so a corrupted packet does not truncate a characterization run.
