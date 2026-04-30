<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works


This project implements a **hardware chaos generator** using the logistic map equation:

x(n+1) = r × x(n) × (1 − x(n))

The system is implemented in digital logic using **fixed-point arithmetic (Q0.12 format)**:

- `x_reg` stores the current state x(n)
- Each clock cycle computes the next value x(n+1)
- The parameter `r` is controlled by `ui_in` (approximately ui_in / 64)
- The initial condition (seed) is provided via `uio_in`

### Key properties:
- Nonlinear dynamics (unlike LFSRs)
- Sensitivity to initial conditions (small seed changes → large divergence)
- Bifurcation behavior (changing `r` alters system dynamics)

### Data path:
1. Compute (1 − x)
2. Multiply x × (1 − x)
3. Multiply by r
4. Normalize back to fixed-point format
5. Feed result back as next state

### Outputs:
- `uo_out[7:0]` → upper 8 bits of chaotic state
- `uio_out[3:0]` → lower 4 bits of state
- `uio_out[7:4]` → iteration counter

---
## How to test

1. Run the provided cocotb testbench
2. Check that:
   - Output is not constant
   - Values evolve over time
   - Changing `r` changes behavior
   - Changing seed produces different sequences

---

### 🔌 On hardware (Tiny Tapeout board)

#### Inputs:
- `ui_in` → controls parameter `r`
  - ~64 → stable
  - ~192 → periodic
  - ~230–255 → chaotic
- `uio_in` → seed (initial value)
  - Example: `0x80` ≈ 0.5

#### Steps:
1. Apply seed using `uio_in`
2. Set `ui_in` value
3. Release reset
4. Observe output changing every clock

#### Expected behavior:
- Low `r` → stable output
- Medium `r` → oscillations
- High `r` → chaotic sequence

---

## External hardware

No external hardware is required.

Optional (for better visualization):
- Logic analyzer or oscilloscope → observe output patterns
- LEDs → display chaotic bits
- Microcontroller/FPGA → capture and plot data
- UART interface → stream values to PC

---
