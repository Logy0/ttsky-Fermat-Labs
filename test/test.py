# SPDX-FileCopyrightText: © 2026 Antoine Lelong
# SPDX-License-Identifier: Apache-2.0

"""cocotb tests for tt_um_Logy_FMAC (8-bit signed FMA: z = a * b + c).

Interface protocol:
    uio[7:0]  DATA   operand byte (input)
    ui[2:0]   CMD    000=load a, 001=load b, 010=load c, 011=GO, 1xx=no-op
    uo[7:0]   Z      result, valid 1 cycle after GO, held until the next GO
"""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CMD_LOAD_A = 0b000
CMD_LOAD_B = 0b001
CMD_LOAD_C = 0b010
CMD_GO = 0b011
CMD_NOP = 0b111


def expected_z(a, b, c):
    """8-bit two's complement result of a*b + c (unsigned encoding)."""
    return (a * b + c) & 0xFF


async def setup(dut):
    # 10 us period = 100 kHz, plenty fast for simulation
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def load_byte(dut, cmd, data):
    """Drive cmd + data; the next rising edge samples them."""
    dut.ui_in.value = cmd
    dut.uio_in.value = data & 0xFF
    await ClockCycles(dut.clk, 1)


async def go_and_read(dut):
    """Issue GO and return the settled 8-bit result."""
    dut.ui_in.value = CMD_GO
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 1)  # edge that latches z
    await ClockCycles(dut.clk, 1)  # let the latch settle
    return dut.uo_out.value.to_unsigned()


async def run_fmac(dut, a, b, c):
    """Load a, b, c, issue GO, and return z."""
    await load_byte(dut, CMD_LOAD_A, a)
    await load_byte(dut, CMD_LOAD_B, b)
    await load_byte(dut, CMD_LOAD_C, c)
    return await go_and_read(dut)


@cocotb.test()
async def test_reset(dut):
    dut._log.info("Reset behavior")
    await setup(dut)

    assert dut.uo_out.value.to_unsigned() == 0, "z must be 0 after reset"

    # GO with nothing loaded: 0*0+0 = 0
    assert await go_and_read(dut) == 0


@cocotb.test()
async def test_corners(dut):
    dut._log.info("Corner cases")
    await setup(dut)

    cases = [
        (0, 0, 0),        # 0
        (1, 1, 1),        # 2
        (127, 127, 127),  # 16256 -> wraps to -128
        (-128, -128, 0),  # 16384 -> 0
        (-128, 127, 0),   # -16256 -> -128
        (127, -128, 127), # -16129 -> -1
        (-128, 1, -128),  # -256 -> 0
        (-127, -127, 0),  # 16129 -> 1
        (100, 100, 0),    # 10000 -> 16
        (-1, -1, -1),     # 0
        (127, 2, 0),      # 254
        (-128, -1, 0),    # 128 -> -128
    ]
    for a, b, c in cases:
        z = await run_fmac(dut, a, b, c)
        exp = expected_z(a, b, c)
        assert z == exp, f"a={a} b={b} c={c}: got {z}, expected {exp}"


@cocotb.test()
async def test_random(dut):
    dut._log.info("Randomized sweep")
    await setup(dut)

    rng = random.Random(0x1234)
    for _ in range(2000):
        a = rng.randint(-128, 127)
        b = rng.randint(-128, 127)
        c = rng.randint(-128, 127)
        z = await run_fmac(dut, a, b, c)
        exp = expected_z(a, b, c)
        assert z == exp, f"a={a} b={b} c={c}: got {z}, expected {exp}"
    dut._log.info("2000 random cases passed")


@cocotb.test()
async def test_protocol(dut):
    dut._log.info("Load/GO protocol")
    await setup(dut)

    # Full load + GO
    z = await run_fmac(dut, 5, 6, 7)
    assert z == expected_z(5, 6, 7)  # 37

    # z is held while no command is active
    dut.ui_in.value = CMD_NOP
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)
    assert dut.uo_out.value.to_unsigned() == 37, "z must be held after GO"

    # Reload only a; b and c are retained
    await load_byte(dut, CMD_LOAD_A, 10)
    z = await go_and_read(dut)
    assert z == expected_z(10, 6, 7)  # 67

    # Repeated GO is idempotent
    z = await go_and_read(dut)
    assert z == 67
