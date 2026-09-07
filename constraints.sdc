###############################################################################
# FMAC (tt_um_Logy_FMAC) - Timing constraints
#
#   Target clock : 50 MHz  (20 ns period)
#   PDK          : sky130A
#   Std cells    : sky130_fd_sc_hd
#
# This file makes the 50 MHz target explicit. It is functionally equivalent
# to the SDC the Tiny Tapeout flow auto-generates from `clock_hz` in
# info.yaml (20 ns clock, 20% IO delays, sky130 driving cells/loads).
#
# KEEP IN SYNC: the clock period here must match `clock_hz` in info.yaml
# (50_000_000 Hz -> 1e9/50e6 = 20 ns).
###############################################################################

current_design tt_um_Logy_FMAC

# ---------------------------------------------------------------------------
# Clock: 50 MHz -> 20 ns period
# ---------------------------------------------------------------------------
create_clock -name clk -period 20.0 [get_ports {clk}]

# Clock quality: on-chip variation + jitter budget (sky130)
set_clock_transition  0.15 [get_clocks {clk}]
set_clock_uncertainty 0.25 [get_clocks {clk}]
set_propagated_clock  [get_clocks {clk}]

# ---------------------------------------------------------------------------
# IO delays: 20% of the clock period = 4 ns (TT flow default).
# A single value sets both min and max (no input skew).
# ---------------------------------------------------------------------------
set io_delay 4.0

# All inputs except the clock
set_input_delay -clock [get_clocks {clk}] $io_delay \
    [remove_from_collection [all_inputs] [get_ports {clk}]]

# All outputs
set_output_delay -clock [get_clocks {clk}] $io_delay [all_outputs]

# ---------------------------------------------------------------------------
# Environment: driving cells and pin loads (sky130_fd_sc_hd)
# ---------------------------------------------------------------------------
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} \
    [remove_from_collection [all_inputs] [get_ports {clk}]]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} [get_ports {clk}]

# ~33.4 fF per output pin
set_load 0.0334 [all_outputs]

# ---------------------------------------------------------------------------
# Design rules
# ---------------------------------------------------------------------------
set_max_transition  0.75 [current_design]
set_max_capacitance 0.20 [current_design]
set_max_fanout      10   [current_design]
