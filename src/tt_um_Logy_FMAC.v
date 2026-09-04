/*
 * Copyright (c) 2026 Antoine Lelong
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_Logy_FMAC - Tiny Tapeout top module for the FMAC project
 *
 * Synchronous 8-bit signed Fused Multiply-Add:  z = a * b + c
 *
 * A 1x1 tile has 16 input-capable pins but the operation needs 24
 * operand bits, so the operands are loaded one byte at a time:
 *
 *   uio[7:0]  DATA   operand byte (input, uio_oe = 0)
 *   ui[2:0]   CMD    000 = load a
 *                    001 = load b
 *                    010 = load c
 *                    011 = GO (compute z)
 *                    1xx = reserved (no-op)
 *   uo[7:0]   Z      8-bit signed result; valid 1 cycle after GO and
 *                    held until the next GO
 *
 * ui[7:3] are reserved and must be tied to 0.
 * After reset a = b = c = z = 0.
 */

`default_nettype none

module tt_um_Logy_FMAC (
    input  wire [7:0] ui_in,    // ui[2:0] = CMD, ui[7:3] reserved
    output wire [7:0] uo_out,   // Z[7:0]
    input  wire [7:0] uio_in,   // DATA[7:0]
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  localparam [2:0] CMD_LOAD_A = 3'd0;
  localparam [2:0] CMD_LOAD_B = 3'd1;
  localparam [2:0] CMD_LOAD_C = 3'd2;
  localparam [2:0] CMD_GO     = 3'd3;

  wire [2:0] cmd = ui_in[2:0];

  reg [7:0] a_reg;
  reg [7:0] b_reg;
  reg [7:0] c_reg;
  reg [7:0] z_reg;

  // Operand registers: level-sensitive byte loads.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= 8'd0;
      b_reg <= 8'd0;
      c_reg <= 8'd0;
    end else begin
      case (cmd)
        CMD_LOAD_A: a_reg <= uio_in;
        CMD_LOAD_B: b_reg <= uio_in;
        CMD_LOAD_C: c_reg <= uio_in;
        default:    ; // keep current value
      endcase
    end
  end

  // Fused multiply-add datapath (combinational).
  wire [7:0] z_comb;
  fmac8 u_fmac (
      .a (a_reg),
      .b (b_reg),
      .c (c_reg),
      .z (z_comb)
  );

  // Result register: latched on GO, held afterwards.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      z_reg <= 8'd0;
    else if (cmd == CMD_GO)
      z_reg <= z_comb;
  end

  assign uo_out  = z_reg;
  assign uio_out = 8'd0;
  assign uio_oe  = 8'd0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:3], 1'b0};

endmodule
