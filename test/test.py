# SPDX-FileCopyrightText: © 2026 Antoine Lelong
# SPDX-License-Identifier: Apache-2.0

"""cocotb tests for tt_um_Logy_FMAC (8-bit signed FMA: z = a * b + c).

Streaming protocol (one result every 2 cycles):
    even cycle (phase 0): ui = a, uio = b
    odd  cycle (phase 1): ui = c  -> z = a*b+c latched
    uo = z, valid one cycle after c (the design free-runs the phase toggle
    starting in phase 0 after reset, so the test stays aligned by driving
    a fixed 2-cycle rhythm).
"""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


def expected_z(a, b, c):
    """8-bit two's complement result of a*b + c (unsigned encoding)."""
    return (a * b + c) & 0xFF


# Reset is applied only once, at the start of the simulation. Re-asserting
# it between tests hits the z output register while it is still being
# read/driven in the gate level netlist.
_reset_done = False


async def setup(dut):
    global _reset_done
    # 10 us period = 100 kHz, plenty fast for simulation
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    if not _reset_done:
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 10)
        dut.rst_n.value = 1
        _reset_done = True
    # Wait an even number of cycles so the design is back in phase 0.
    await ClockCycles(dut.clk, 2)


async def run_fmac(dut, a, b, c):
    """Stream one (a,b,c) triple and return the settled z."""
    # phase 0: load a (ui) and b (uio)
    dut.ui_in.value = a & 0xFF
    dut.uio_in.value = b & 0xFF
    await ClockCycles(dut.clk, 1)
    # phase 1: load c (ui); z = a*b+c latched at this edge
    dut.ui_in.value = c & 0xFF
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 1)
    # Let the result register settle (phase is back to 0).
    await Timer(10, unit="ns")
    return dut.uo_out.value.to_unsigned()


@cocotb.test()
async def test_reset(dut):
    dut._log.info("Reset behavior")
    await setup(dut)
    assert dut.uo_out.value.to_unsigned() == 0, "z must be 0 after reset"


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
async def test_streaming(dut):
    dut._log.info("Back-to-back streaming (one result / 2 cycles)")
    await setup(dut)

    triples = [
        (5, 6, 7),
        (10, 6, 7),
        (10, 20, 7),
        (-3, -4, 5),
        (127, 127, 127),
        (-128, -128, 0),
    ]
    for a, b, c in triples:
        z = await run_fmac(dut, a, b, c)
        exp = expected_z(a, b, c)
        assert z == exp, f"a={a} b={b} c={c}: got {z}, expected {exp}"
