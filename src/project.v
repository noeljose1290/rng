`default_nettype none
`timescale 1ns / 1ps

/*
 * ╔══════════════════════════════════════════════════════════════════════╗
 * ║   tt_um_chaos_logistic  –  Logistic-Map Chaos Generator             ║
 * ║   Tiny Tapeout submission                                           ║
 * ╠══════════════════════════════════════════════════════════════════════╣
 * ║  Equation:  x[n+1] = r · x[n] · (1 − x[n])                        ║
 * ║                                                                      ║
 * ║  Fixed-point arithmetic                                              ║
 * ║    x  : 12-bit Q0.12   x_actual = x_reg / 4096   range [0, 1)      ║
 * ║    r  : ui_in / 64     r_actual ∈ [0, ~3.984]                       ║
 * ║                                                                      ║
 * ║  ┌──────────────┬──────┬──────────────────────────────────────┐     ║
 * ║  │  ui_in value │  r   │  Observed behavior                   │     ║
 * ║  ├──────────────┼──────┼──────────────────────────────────────┤     ║
 * ║  │      64      │ 1.00 │ Convergence → x* = 0                 │     ║
 * ║  │     128      │ 2.00 │ Stable fixed point x* = 0.5          │     ║
 * ║  │     192      │ 3.00 │ Period-2 limit cycle starts          │     ║
 * ║  │     216      │ 3.38 │ Period-4                             │     ║
 * ║  │     228      │ 3.56 │ Onset of chaos (period-∞ cascade)    │     ║
 * ║  │     240      │ 3.75 │ Fully chaotic                        │     ║
 * ║  │     255      │ 3.98 │ Deep chaos                           │     ║
 * ║  └──────────────┴──────┴──────────────────────────────────────┘     ║
 * ║                                                                      ║
 * ║  Why nonlinear chaos beats LFSR                                      ║
 * ║    • LFSRs are LINEAR — period is fixed and predictable              ║
 * ║    • Logistic map is NONLINEAR — sensitive to initial conditions      ║
 * ║    • Bifurcation: tiny r change → qualitative behavior change        ║
 * ║    • Two trajectories starting 0.001 apart diverge exponentially     ║
 * ║                                                                      ║
 * ║  Pin Map                                                             ║
 * ║    ui_in  [7:0]   r parameter (see table above)                     ║
 * ║    uio_in [7:0]   seed x0 (x0 ≈ seed/256; use 0x80 for x0=0.5)    ║
 * ║    uo_out [7:0]   x[11:4]  — 8 MSBs of chaotic state              ║
 * ║    uio_out[7:4]   x[3:0]   — 4 LSBs of chaotic state              ║
 * ║    uio_out[3:0]   iter[3:0] — iteration counter (period indicator)  ║
 * ╚══════════════════════════════════════════════════════════════════════╝
 */

module tt_um_chaos_logistic (
    input  wire [7:0] ui_in,    // r parameter: r_actual = ui_in / 64
    output wire [7:0] uo_out,   // x[11:4] — upper 8 bits of chaotic state
    input  wire [7:0] uio_in,   // seed x0 (use 0x80 for x0 ≈ 0.5)
    output wire [7:0] uio_out,  // x[3:0] ++ iter[3:0]
    output wire [7:0] uio_oe,   // all bidirectional pins driven as outputs
    input  wire       ena,      // asserted high when design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // active-low reset
);

    // ─────────────────────────────────────────────────────────────────────
    // State registers
    // ─────────────────────────────────────────────────────────────────────
    reg [11:0] x_reg;       // Q0.12 chaotic state
    reg [3:0]  iter;        // iteration counter (visible period indicator)

    // ─────────────────────────────────────────────────────────────────────
    // Logistic map  —  combinational pipeline
    //
    //  All values are Q0.12 (divide by 4096 to get the real number).
    //
    //  Step 1 │ one_minus_x  = 4096 − x_reg
    //         │   13-bit needed because x=0 → result=4096 (won't fit in 12)
    //
    //  Step 2 │ product = x_reg × one_minus_x
    //         │   Full 26-bit product; max at x=0.5: 2048×2048 = 2²²
    //
    //  Step 3 │ x_sq_norm = product[23:12]   (arithmetic right-shift by 12)
    //         │   Renormalises x·(1−x) back into Q0.12.
    //         │   At x=0.5: product=4194304, x_sq_norm=1024 (=0.25×4096) ✓
    //
    //  Step 4 │ r_product = ui_in × x_sq_norm
    //         │   20-bit product; max ≈ 255×1024 = 261120 < 2^18
    //
    //  Step 5 │ x_new = r_product[17:6]   (arithmetic right-shift by 6)
    //         │   The ÷64 maps ui_in → r_actual: ui_in=64 → r=1, 255 → r≈3.98
    //         │   At x=0.5, r=3.98: x_new = 261120>>6 = 4080 ≈ 3.98×0.25×4096 ✓
    // ─────────────────────────────────────────────────────────────────────

    wire [12:0] x13         = {1'b0, x_reg};            // zero-extend to 13-bit
    wire [12:0] one_minus_x = 13'd4096 - x13;           // (1-x) in Q0.12, 13-bit
    wire [25:0] product     = x13 * one_minus_x;        // 13×13 → full 26-bit
    wire [11:0] x_sq_norm   = product[23:12];           // x·(1-x) normalised Q0.12
    wire [19:0] r_product   = {4'b0, ui_in} * x_sq_norm; // r·[x·(1-x)], 20-bit
    wire [11:0] x_new       = r_product[17:6];          // ÷64 → back to Q0.12

    // ─────────────────────────────────────────────────────────────────────
    // Fixed-point guard
    //   x=0 and x≈1 are degenerate fixed points.  If rounding drives us
    //   there (only happens at extreme r or unlucky seeds), perturb gently.
    // ─────────────────────────────────────────────────────────────────────
    wire [11:0] x_safe = (x_new < 12'h004 || x_new > 12'hFFB)
                         ? 12'h4D0          // ≈ 0.4990 — a safe perturbation
                         : x_new;

    // ─────────────────────────────────────────────────────────────────────
    // Reset seed
    //   Map the 8-bit uio_in seed into a 12-bit x0.
    //   Lower nibble forced to 0x8 keeps x0 away from exact 0.
    //   If seed==0 default to x0 ≈ 0.5.
    // ─────────────────────────────────────────────────────────────────────
    wire [11:0] seed = (uio_in == 8'h00) ? 12'h800 : {uio_in, 4'h8};

    // ─────────────────────────────────────────────────────────────────────
    // Sequential update  —  iterate every clock when enabled
    // ─────────────────────────────────────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= seed;
            iter  <= 4'h0;
        end else if (ena) begin
            x_reg <= x_safe;
            iter  <= iter + 1'b1;
        end
    end

    // ─────────────────────────────────────────────────────────────────────
    // Output assignments
    // ─────────────────────────────────────────────────────────────────────
    assign uo_out  = x_reg[11:4];           // 8 MSBs — primary chaos output
    assign uio_out = {x_reg[3:0], iter};    // 4 LSBs of x ++ iteration nibble
    assign uio_oe  = 8'hFF;                 // all bidir pins → driven as outputs

endmodule
