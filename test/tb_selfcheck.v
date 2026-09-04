`timescale 1ns / 1ps

/*
 * Self-checking testbench for tt_um_Logy_FMAC (plain iverilog, no cocotb).
 *
 * Quick local run:
 *   iverilog -g2005 -o /tmp/fmac.vvp src/fmac8.v src/tt_um_Logy_FMAC.v test/tb_selfcheck.v
 *   vvp /tmp/fmac.vvp
 */

module tb_selfcheck;

  reg        clk = 1'b0;
  reg        rst_n;
  reg        ena = 1'b1;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_Logy_FMAC dut (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  always #5 clk = ~clk;

  integer errors;
  integer i;

  // Drive a command + byte and wait for the clock edge that samples it.
  task automatic load_byte;
    input [2:0] cmd;
    input [7:0] data;
    begin
      ui_in  = cmd;
      uio_in = data;
      @(posedge clk);
      #1;
    end
  endtask

  // Load a, b, c, issue GO, and compare z against an independent reference.
  task automatic check;
    input [7:0] a;
    input [7:0] b;
    input [7:0] c;
    // NB: not named "ref" - iverilog's lexer treats "ref" as a keyword
    reg   signed [15:0] refval;
    begin
      refval = $signed({{8{a[7]}}, a}) * $signed({{8{b[7]}}, b})
             + $signed({{8{c[7]}}, c});
      load_byte(3'd0, a);
      load_byte(3'd1, b);
      load_byte(3'd2, c);
      load_byte(3'd3, 8'd0);
      if (uo_out !== refval[7:0]) begin
        errors = errors + 1;
        $display("FAIL: a=%0d b=%0d c=%0d  z=%0d expected %0d",
                 $signed(a), $signed(b), $signed(c),
                 $signed(uo_out), $signed(refval[7:0]));
      end
    end
  endtask

  initial begin
    $dumpfile("tb_selfcheck.vcd");
    $dumpvars(0, tb_selfcheck);

    errors = 0;
    rst_n  = 1'b0;
    ui_in  = 8'd0;
    uio_in = 8'd0;
    repeat (5) @(posedge clk);
    #1;
    rst_n = 1'b1;
    @(posedge clk);
    #1;

    // z must be 0 after reset
    if (uo_out !== 8'd0) begin
      errors = errors + 1;
      $display("FAIL: z != 0 after reset");
    end

    // uio outputs must be tied to 0 (input mode)
    if (uio_out !== 8'd0 || uio_oe !== 8'd0) begin
      errors = errors + 1;
      $display("FAIL: uio_out/uio_oe not tied to 0");
    end

    // GO with nothing loaded: 0*0+0 = 0
    load_byte(3'd3, 8'd0);
    if (uo_out !== 8'd0) begin
      errors = errors + 1;
      $display("FAIL: GO with no loads did not return 0");
    end

    // Hand-computed corner cases (operands in two's complement)
    check(8'd0,   8'd0,   8'd0);    // 0
    check(8'd1,   8'd1,   8'd1);    // 2
    check(8'd127, 8'd127, 8'd127);  // 16256  -> 128
    check(8'd128, 8'd128, 8'd0);    // 16384  -> 0
    check(8'd128, 8'd127, 8'd0);    // -16256 -> 128
    check(8'd127, 8'd128, 8'd127);  // -16129 -> 255
    check(8'd128, 8'd1,   8'd128);  // -256   -> 0
    check(8'd127, 8'd2,   8'd0);    // 254    -> 254
    check(8'd128, 8'd2,   8'd0);    // -256   -> 0
    check(8'd128, 8'd255, 8'd0);    // 128    -> 128
    check(8'd100, 8'd100, 8'd0);    // 10000  -> 16
    check(8'd255, 8'd255, 8'd255);  // 0
    check(8'd129, 8'd129, 8'd0);    // 16129  -> 1

    // Randomized sweep against the reference
    for (i = 0; i < 4000; i = i + 1)
      check($random, $random, $random);

    if (errors == 0)
      $display("SELF-CHECK PASSED: 13 corner cases + 4000 random cases");
    else
      $display("SELF-CHECK FAILED: %0d error(s)", errors);
    $finish;
  end

endmodule
