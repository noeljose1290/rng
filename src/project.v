`default_nettype none
`timescale 1ns / 1ps

module tt_um_chaos_logistic (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ------------------------------------------------------------
    // State
    // ------------------------------------------------------------
    reg [11:0] x_reg;   // Q0.12
    reg [3:0]  iter;

    // ------------------------------------------------------------
    // Logistic map datapath
    // ------------------------------------------------------------
    wire [12:0] x13         = {1'b0, x_reg};
    wire [12:0] one_minus_x = 13'd4096 - x13;
    wire [25:0] product     = x13 * one_minus_x;
    wire [11:0] x_sq_norm   = product[23:12];
    wire [19:0] r_product   = {4'b0, ui_in} * x_sq_norm;
    wire [11:0] x_new       = r_product[17:6];

    // ------------------------------------------------------------
    // Safety clamp (avoid collapse to 0 or 1)
    // ------------------------------------------------------------
    wire [11:0] x_safe =
        (x_new < 12'h004 || x_new > 12'hFFB)
        ? 12'h4D0
        : x_new;

    // ------------------------------------------------------------
    // Seed
    // ------------------------------------------------------------
    wire [11:0] seed =
        (uio_in == 8'h00) ? 12'h800 : {uio_in, 4'h8};

    // ------------------------------------------------------------
    // Sequential update
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= seed;
            iter  <= 4'h0;
        end else if (ena) begin
            x_reg <= x_safe;
            iter  <= iter + 1'b1;
        end
    end

    // ------------------------------------------------------------
    // ✅ GL-SAFE OUTPUTS (CRITICAL FIX)
    // ------------------------------------------------------------
    assign uo_out[7:0]  = rst_n ? x_reg[11:4]           : 8'h00;
    assign uio_out[7:0] = rst_n ? {x_reg[3:0], iter}    : 8'h00;
    assign uio_oe       = 8'hFF;

endmodule
