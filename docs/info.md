<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a hardware chaos generator using the logistic map equation:

x
n+1
	​

=r⋅x
n
	​

⋅(1−x
n
	​

)

The system is realized entirely in digital logic using fixed-point arithmetic (Q0.12 format):

x_reg stores the current state x
n
	​

Each clock cycle computes the next value x
n+1
	​

The parameter r is controlled by ui_in (r ≈ ui_in / 64)
The initial condition (seed) is provided via uio_in
Key properties:
Nonlinear dynamics (unlike LFSRs)
Sensitivity to initial conditions (small seed changes → large divergence)
Bifurcation behavior (changing r alters system dynamics)
Data path:
Compute 1−x
n
	​

Multiply x
n
	​

⋅(1−x
n
	​

)
Multiply by parameter r
Normalize result back to fixed-point format
Feed result back as next state
Outputs:
uo_out[7:0] → upper 8 bits of chaotic state
uio_out[3:0] → lower 4 bits of state
uio_out[7:4] → iteration counter (helps observe periodicity)

## How to test

Explain how to use your project

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
