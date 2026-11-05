# CHIPLET_MODEL_BASIC

Verilog model of a chiplet die-to-die interconnect link, built for my research on *Chiplet Statistical Testing* at Danang University of Science and Technology. The link generates traffic, injects configurable faults on selected lanes and measures packet/lane error rates, with a self-checking testbench in Icarus Verilog.

The goal is to compare sampling strategies (random, uniform and BONR) for mapping the safe operating region of the link as a function of fault parameters.

## Status

- Multi-lane link, packet generator/checker, link controller, fault injector and error monitor are implemented and pass the self-checking testbench.
- Retraining is deliberately disabled: one corrupted packet must not truncate a characterization run, so faults are measured as packet/lane errors.
- Cocotb testbench and the BONR sampling scripts are not done yet.

## Architecture

```mermaid
flowchart LR
    PG[packet_generator] --> TX[tx]
    TX --> FI[fault_injector]
    FI --> ML[multi_lane_link]
    ML --> RX[rx]
    RX --> PC[packet_checker]
    LC[link_controller] -. state / retrain .-> TX
    LC -.-> RX
    PC --> EM[error_monitor]
    FI -. injected faults .-> EM
```

## Repository layout

```text
rtl/    RTL source
tb/     Self-checking testbench
build/  Generated simulation artifacts (not tracked)
```

| File | Role |
|---|---|
| `rtl/top.v` | FPGA physical top (`chiplet_interconnect_top`): real I/O only, fixed demo configuration |
| `rtl/core.v` | `chiplet_interconnect_core`: integrates all blocks; use this directly for Cocotb |
| `rtl/packet_generator.v` | Traffic source (rate set by `traffic_level`) |
| `rtl/tx.v` / `rtl/rx.v` | Transmitter / receiver |
| `rtl/multi_lane_link.v` | Lane model between TX and RX |
| `rtl/fault_injector.v` | Configurable fault injection on selected lanes |
| `rtl/packet_checker.v` | Verifies received packets |
| `rtl/link_controller.v` | Link training / state machine / retrain request |
| `rtl/error_monitor.v` | Packet and error statistics |
| `tb/tb_chiplet.v` | Self-checking testbench |
| `run_tb.ps1` | Compile and run script (Windows + Icarus Verilog) |

## Configuration

Parameters of `chiplet_interconnect_core`:

| Parameter | Default | Meaning |
|---|---|---|
| `WIDTH` | 32 | Packet width (bits) |
| `NUM_LANES` | 2 | Number of lanes |
| `LANE_WIDTH` | 16 | Bits per lane |

See the header of `rtl/core.v` for the full port list and control/status signals (`link_enable`, `fault_rate`, `burst_length`, `fault_lane_mask`, `link_up`, `total_packets`, `error_packets`, ...).

## Quick start

Requires [Icarus Verilog](https://bleyer.org/icarus/) with `-g2012`.

Windows:

1. Open `run_tb.ps1` and set `$iverilog` / `$vvp` to your install path.
2. Run `powershell -ExecutionPolicy Bypass -File .\run_tb.ps1`

Any OS:

```bash
mkdir -p build
iverilog -g2012 -Wno-timescale -o build/tb_chiplet.vvp \
  tb/tb_chiplet.v rtl/core.v rtl/packet_generator.v rtl/tx.v rtl/fault_injector.v \
  rtl/multi_lane_link.v rtl/rx.v rtl/packet_checker.v rtl/link_controller.v rtl/error_monitor.v
vvp build/tb_chiplet.vvp
```

## Research context

Goal: map the safe operating region of the link as a function of fault parameters (e.g. `fault_rate`, `burst_length`, `fault_duration`), separated from the unsafe one by the boundary `p_fail = θ`. Three sampling strategies are compared:

1. **Random** sampling
2. **Uniform** (grid) sampling
3. **BONR** (Boundary-Oriented Neighborhood Refinement): concentrates samples and refines neighboring points around the `p_fail = θ` boundary

Results: _to be added (figures, number of samples vs boundary error)._

## Author

**Vo Quoc Tuan** — Integrated Circuit Design, Danang University of Science and Technology
GitHub: [@qtundeptraidut](https://github.com/qtundeptraidut)
