# TPU Systolic Array HW Accelerator

Verilog implementation of a small tensor-processing style matrix-multiplication accelerator built around a 4x4 systolic array datapath. The design is driven by a testbench that preloads input matrices into global buffers, triggers computation with matrix dimensions `(K, M, N)`, and checks the packed output matrix against golden vectors.

## Overview

This repository contains a compact RTL prototype of a TPU-like accelerator for matrix multiplication:

- Input activation matrix `A` is stored in a 32-bit global buffer.
- Weight matrix `B` is stored in a second 32-bit global buffer.
- Output matrix `C` is written back in 128-bit words, packing four 32-bit partial sums per entry.
- The compute core streams data through a 4x4 systolic-style multiply-accumulate array.

At a high level, the accelerator computes:

$$
C_{M \times N} = A_{M \times K} \times B_{K \times N}
$$

The implementation tiles the output space into 4-column packed words and accumulates 16 processing elements in parallel before emitting data to the output buffer.

## Repository Layout

| File | Purpose |
| --- | --- |
| `TPU.v` | Top-level accelerator RTL, including state machine, data loaders, multiply array, and output packing. |
| `global_buffer.v` | Parameterized single-port global buffer used for A, B, and C storage in the test environment. |
| `PATTERN.v` | Verification pattern generator and golden checker. It preloads A/B buffers, drives `(K, M, N)`, waits for `busy`, and compares output data. |
| `TESTBENCH.v` | Top-level testbench connecting `PATTERN` and `TPU`. |
| `README.md` | Project documentation. |

## Design Summary

### Top-level interface

The `TPU` module exposes three logical memory channels:

- `A_*`: read-only access to packed 32-bit rows from the A buffer
- `B_*`: read-only access to packed 32-bit rows from the B buffer
- `C_*`: write path for packed 128-bit output words

Control inputs:

- `in_valid`: latches a new matrix job
- `K`, `M`, `N`: matrix dimensions
- `busy`: asserted while the accelerator is processing the current job

### Compute organization

The RTL in `TPU.v` is organized around four phases encoded by the FSM:

1. `IDLE`: waits for a valid job.
2. `READ`: streams A and B buffer data into local shift registers.
3. `OUTPUT`: packs four 32-bit partial sums into one 128-bit output word and writes to C.
4. `FINISH`: clears control state and drops `busy`.

The datapath uses:

- 16 multiply lanes
- 16 partial-sum registers
- staged input delay lines for A and B operands
- packed 128-bit writeback to the output buffer

### Buffer behavior

`global_buffer.v` implements a parameterized memory used by the testbench for all three operand/result buffers.

- Reset clears the entire memory array.
- Writes occur when `wr_en = 1`.
- Reads return `data_out` when `wr_en = 0`.
- The buffer logic is triggered on the negative clock edge in this environment.

## Verification Flow

`PATTERN.v` provides the complete functional test flow:

1. Reset the DUT.
2. Open the input pattern file.
3. Read one test case worth of `K`, `M`, `N`, matrix `A`, matrix `B`, and golden `C`.
4. Preload `gbuff_A` and `gbuff_B` directly.
5. Pulse `in_valid` for one cycle.
6. Wait for the DUT to finish.
7. Compare `gbuff_C` against the golden result.

The testbench expects pattern data at:

```text
../input/verif1/input.txt
```

That dataset is not present in this workspace, so simulation cannot be reproduced here without adding the verification input files.

## How To Run

This repository does not include simulator scripts, Makefiles, or the verification input directory, but a typical Icarus Verilog flow would look like this once the input vectors are available:

```bash
iverilog -g2012 -DRTL -o simv TESTBENCH.v
vvp simv
```

Notes:

- `TESTBENCH.v` includes both `PATTERN.v` and `TPU.v`.
- `PATTERN.v` itself includes `global_buffer.v`.
- The relative input path in `PATTERN.v` must resolve correctly from the directory where the simulator runs.

## Current Workspace Status

From this workspace inspection:

- The RTL sources are present.
- No local simulator binary was found in the shell environment.
- No `input/verif1/input.txt` dataset was found adjacent to this repository.

If you want a one-command simulation flow, the next useful addition would be a small `Makefile` plus an `input/` directory layout documented in the repo.

## Included Reference Images

These original images are preserved for quick visual context:

![image](https://user-images.githubusercontent.com/59387743/214672108-84c2a86e-aa9b-47f8-b3a5-b7a6728de4e8.png)
![image](https://user-images.githubusercontent.com/59387743/214672245-abde68df-89de-4197-864f-924ebd10573f.png)
![image](https://user-images.githubusercontent.com/59387743/214672526-cabc0563-b628-41c9-b1fa-9eae61badb45.png)
![image](https://user-images.githubusercontent.com/59387743/214672704-dce0940e-2acc-4c5a-972e-e749c473c8b3.png)
