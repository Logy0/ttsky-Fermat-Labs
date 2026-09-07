![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# FMAC — 8-bit Signed Fused Multiply-Add

A [Tiny Tapeout](https://tinytapeout.com) project by **Antoine Lelong** (Discord: `Logy`).

**FMAC** is a synchronous 8-bit signed **fused multiply-add** unit that computes:

```
z = a * b + c
```

where `a`, `b`, `c`, and `z` are 8-bit two's-complement integers.

- [Project documentation & datasheet](docs/info.md)

## Goal

FMAC demonstrates how to implement a real arithmetic datapath on a single
**1×1** Tiny Tapeout tile while working within the tile's limited I/O budget.

The operation needs **24 input bits** (`a`, `b`, `c`), but a 1×1 tile only
exposes **16 input-capable pins**. The design solves this by
*time-multiplexing* the operands across clock cycles and using **both** input
buses as data, reaching a throughput of **one result every 2 cycles**.

The fused multiply-add is also a fundamental building block in DSP,
polynomial evaluation, and dot-product / ML workloads, so the project doubles
as a small reusable arithmetic core.

## How it works

### Datapath

The core (`src/fmac8.v`) is a purely combinational fused multiply-add:

```
a[7:0] ──┐
         ├─► [8×8 signed multiply] ─► p[15:0] ─┐
b[7:0] ──┘                                      [+] ─► s[15:0]
c[7:0] ──► [sign-extend to 16] ─────────────────┘        │
                                                          ▼
                                                 z[7:0] = s[7:0]
```

- The product and sum are carried in **16 bits**, so no intermediate overflow
  is possible (`a·b` ∈ [−16256, 16384], `a·b+c` ∈ [−16384, 16511]).
- `z` is the **low 8 bits** of the sum — standard mod-256 wraparound
  (e.g. `100·100 + 0 = 10000 → z = 240 = −16`).

### Streaming protocol

The top module (`src/tt_um_Logy_FMAC.v`) free-runs a 2-phase toggle (starting
in phase 0 after reset). Both input buses carry data:

| Cycle | `ui[7:0]` | `uio[7:0]` | `uo[7:0]` | Action |
|:-----:|:---------:|:----------:|:---------:|--------|
| even (phase 0) | `a` | `b` | previous `z` | capture `a`, `b` |
| odd (phase 1) | `c` | (unused) | — | capture `c`, latch `z = a·b + c` |

A result is valid on `uo` one cycle after its `c` is presented —
**one result every 2 cycles**.

## How to use the chip

### Pinout

| Pin | Name | Direction | Role |
|-----|------|-----------|------|
| `ui[7:0]` | `A/C` | input | `a` on even cycles, `c` on odd cycles |
| `uio[7:0]` | `B` | input | `b` on even cycles (unused on odd cycles) |
| `uo[7:0]` | `Z` | output | 8-bit signed result |

The tile also receives `clk` (50 MHz), `rst_n` (active-low reset), and `ena`
(ignored) from the Tiny Tapeout platform. `uio` is used as an input only.

### Usage

1. Hold `rst_n` low for a few cycles, then release it. The design starts in
   phase 0 with `z = 0`.
2. On an **even** cycle, drive `ui = a` and `uio = b`.
3. On the next **odd** cycle, drive `ui = c`.
4. Read `z` on `uo` the following even cycle.
5. Repeat with the next `(a, b, c)` triple for a continuous stream.

Because the design free-runs the phase toggle and there is no separate
start/valid signal (no spare pins), the host — which drives `clk` and `rst_n`
— must stay **phase-aligned**: count cycles from reset.

### Example: compute `z = 5 × 6 + 7 = 37`

After reset (phase 0), drive the pins as follows:

| Cycle | Phase | `ui` (A/C) | `uio` (B) | `uo` (Z) |
|:-----:|:-----:|:----------:|:---------:|:--------:|
| 0 | load a,b | `5` | `6` | `0` |
| 1 | load c | `7` | x | `0` |
| 2 | load a,b | … | … | **`37`** ✓ |

On cycle 2, `uo` reads `37`. Keep feeding the next triple every 2 cycles for a
back-to-back stream.

## How to test

- **cocotb** (`test/test.py`, run via the `test/` Makefile or the GitHub
  Actions test workflow): reset behavior, corner cases, 2000 randomized
  triples against a Python reference, and back-to-back streaming.
- **Self-checking iverilog testbench** (`test/tb_selfcheck.v`) for quick local
  runs without cocotb:

  ```sh
  iverilog -g2005 -o /tmp/fmac.vvp src/fmac8.v src/tt_um_Logy_FMAC.v test/tb_selfcheck.v
  vvp /tmp/fmac.vvp
  ```

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper
than ever to get your digital and analog designs manufactured on a real chip.
To learn more and get started, visit https://tinytapeout.com.

The GitHub action builds the ASIC files automatically using
[LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/).

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## Share your project

Share your project on your social network of choice:

- LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
- Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
- X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
- Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
