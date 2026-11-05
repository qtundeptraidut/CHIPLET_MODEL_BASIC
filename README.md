# CHIPLET_MODEL_BASIC

![Verilog](https://img.shields.io/badge/HDL-Verilog--2012-blue)
![Simulator](https://img.shields.io/badge/sim-Icarus%20Verilog-orange)
![Cocotb](https://img.shields.io/badge/verification-Cocotb-green)
![FPGA](https://img.shields.io/badge/FPGA-Libero%20SoC-lightgrey)

A parameterizable **Verilog model of a chiplet die-to-die interconnect link** with built-in **fault injection** and **error monitoring**. It is the RTL platform for the research project *Chiplet Statistical Testing*, which maps the safe operating region of a link by comparing sampling strategies (random, uniform, and BONR).

## Features

- Multi-lane link (default: 32-bit packets over 2 lanes x 16 bits)
- Packet generator and packet checker for end-to-end data integrity
- Link controller with training modes, link state and retrain request
- Runtime-configurable fault injector: type, rate, burst length, duration, per-lane mask
- Error monitor: total/error packet counters, per-lane error counters, injected-fault counter, overflow flag
- Self-checking testbench (Icarus Verilog) and a thin FPGA top wrapper

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

> Simplified block view. Update the arrows if the connections in `core.v` differ.

## Repository layout

| File | Role |
|---|---|
| `top.v` | FPGA physical top (`chiplet_interconnect_top`): exposes only real I/O, fixed demo configuration |
| `core.v` | `chiplet_interconnect_core`: integrates all blocks; use this directly for Cocotb |
| `packet_generator.v` | Traffic source (rate set by `traffic_level`) |
| `tx.v` / `rx.v` | Transmitter / receiver |
| `multi_lane_link.v` | Lane model between TX and RX |
| `fault_injector.v` | Configurable fault injection on selected lanes |
| `packet_checker.v` | Verifies received packets |
| `link_controller.v` | Link training / state machine / retrain request |
| `error_monitor.v` | Packet and error statistics |
| `tb_chiplet.v` | Self-checking testbench |
| `run_tb.ps1` | Compile and run script (Windows + Icarus Verilog) |

## Configuration

Parameters of `chiplet_interconnect_core`:

| Parameter | Default | Meaning |
|---|---|---|
| `WIDTH` | 32 | Packet width (bits) |
| `NUM_LANES` | 2 | Number of lanes |
| `LANE_WIDTH` | 16 | Bits per lane |

Main control inputs:

| Signal | Width | Meaning |
|---|---|---|
| `link_enable` | 1 | Enable the link |
| `training_mode` | 2 | Link training mode |
| `traffic_level` | 8 | Traffic intensity |
| `fault_enable` | 1 | Enable fault injection |
| `fault_type` | 2 | Fault type |
| `fault_rate` | 8 | Fault probability/rate |
| `burst_length` | 8 | Length of a fault burst |
| `fault_duration` | 8 | Duration of an injected fault |
| `fault_lane_mask` | 2 | Lanes affected by faults |

Status outputs include `link_up`, `link_state`, `lane_enable`, `retrain_req`, `fault_active`, `fault_inject_count`, `total_packets`, `error_packets`, `lane_error_cnt0..3`, `injected_faults`, `error_overflow`.

## Quick start

### Requirements

- [Icarus Verilog](https://bleyer.org/icarus/) (`iverilog`, `vvp`) with `-g2012`

### Run the testbench (Windows)

1. Open `run_tb.ps1` and set `$iverilog` / `$vvp` to your install path.
2. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_tb.ps1
```

### Run manually (any OS)

```bash
mkdir -p build
iverilog -g2012 -Wno-timescale -o build/tb_chiplet.vvp \
  tb_chiplet.v core.v packet_generator.v tx.v fault_injector.v \
  multi_lane_link.v rx.v packet_checker.v link_controller.v error_monitor.v
vvp build/tb_chiplet.vvp
```

## Research context: Chiplet Statistical Testing

Goal: map the safe operating region of the link as a function of fault parameters (e.g. `fault_rate`, `burst_length`, `fault_duration`), where the safe region is separated from the unsafe one by the boundary `p_fail = θ`.

Three sampling strategies are compared:

1. **Random** sampling
2. **Uniform** (grid) sampling
3. **BONR** (Boundary-Oriented Neighborhood Refinement): concentrates samples and refines neighboring points around the `p_fail = θ` boundary

Results: _to be added (figures, number of samples vs boundary error)._

## Roadmap

- [ ] Cocotb testbench for `chiplet_interconnect_core`
- [ ] Python scripts for random / uniform / BONR sampling and plotting
- [ ] Result figures and comparison table
- [ ] FPGA implementation report (Libero SoC)

## Author

**Vo Quoc Tuan** - Integrated Circuit Design, Danang University of Science and Technology
GitHub: [@qtundeptraidut](https://github.com/qtundeptraidut)

## License


