/*
 * Copyright (c) 2026 Antoine Lelong
 * SPDX-License-Identifier: Apache-2.0
 *
 * fmac8 - 8-bit signed Fused Multiply-Add datapath
 *
 *   z = a * b + c
 *
 * a, b, c, z are 8-bit two's complement. The product and the sum are
 * carried in 16 bits, so no intermediate overflow is possible:
 *   a*b   in [-16256,  16384]
 *   a*b+c in [-16384,  16511]
 * z is the low 8 bits of the sum (mod-256 wraparound).
 */

`default_nettype none

module fmac8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [7:0] c,
    output wire [7:0] z
);

  // Sign-extend the operands to 16 bits (assignment to a wider signed
  // wire sign-extends the right-hand side).
  wire signed [15:0] a16 = a;
  wire signed [15:0] b16 = b;
  wire signed [15:0] c16 = c;

  // 8x8 signed multiply -> 16-bit product, plus sign-extended c.
  wire signed [15:0] prod = a16 * b16;
  wire signed [15:0] sum  = prod + c16;

  // Truncate to 8 bits (mod-256 wraparound).
  assign z = sum[7:0];

endmodule
