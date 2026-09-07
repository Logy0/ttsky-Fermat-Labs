/*
 * Copyright (c) 2026 Antoine Lelong
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_Logy_FMAC - Tiny Tapeout top module for the FMAC project
 *
 * Synchronous 8-bit signed Fused Multiply-Add:  z = a * b + c
 *
 * Streaming protocol (one result every 2 cycles). Both input buses carry
 * data, so two operands are loaded per cycle:
 *
 *   even cycle (phase 0): ui_in = a, uio_in = b
 *                         -> capture a and b
 *   odd  cycle (phase 1): ui_in = c, uio_in = don't care
 *                         -> capture c and latch z = a*b + c
 *
 *   uo_out = z, valid one cycle after c is presented (every 2 cycles).
 *
 * The design free-runs a 2-phase toggle starting in phase 0 after reset.
 * The host (which drives clk and rst_n) must stay phase-aligned.
 * uio is used as an input only (uio_oe = 0).
 */

`default_nettype none

module tt_um_Logy_FMAC (
    input  wire [7:0] ui_in,    // phase 0: a[7:0]; phase 1: c[7:0]
    output wire [7:0] uo_out,   // z[7:0]
    input  wire [7:0] uio_in,   // phase 0: b[7:0]; phase 1: unused
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // Free-running 2-phase toggle.
  reg        phase;   // 0 = capture a,b; 1 = capture c + latch z
  reg  [7:0] a_reg;
  reg  [7:0] b_reg;
  reg  [7:0] z_reg;

  // Fused multiply-add datapath (combinational).
  // In phase 1, ui_in carries c, so z_comb = a_reg * b_reg + c.
  wire [7:0] z_comb;
  fmac8 u_fmac (
      .a (a_reg),
      .b (b_reg),
      .c (ui_in),
      .z (z_comb)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phase <= 1'b0;
      a_reg <= 8'd0;
      b_reg <= 8'd0;
      z_reg <= 8'd0;
    end else begin
      phase <= ~phase;
      if (!phase) begin
        a_reg <= ui_in;   // a
        b_reg <= uio_in;  // b
      end else begin
        z_reg <= z_comb;  // z = a*b + c
      end
    end
  end

  assign uo_out  = z_reg;
  assign uio_out = 8'd0;
  assign uio_oe  = 8'd0;

  // Unused inputs
  wire _unused = &{ena, 1'b0};

endmodule
