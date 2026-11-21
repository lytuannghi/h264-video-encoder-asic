###############################################################################
# File: h264_timing.sdc
# Module: h264_video_encoder_top
# Target Frequency: 200.0 MHz (5.000 ns Period)
# Technology: TSMC 28nm HPC+ Standard Cell Library (typical 0.9V, 25C)
###############################################################################

# Primary Clock Definition
create_clock -name clk -period 5.000 -waveform {0.000 2.500} [get_ports clk]

# Clock Uncertainty & Jitter
set_clock_uncertainty -setup 0.150 [get_clocks clk]
set_clock_uncertainty -hold  0.050 [get_clocks clk]
set_clock_transition 0.080 [get_clocks clk]

# Input Delays (30% of clock period budget)
set_input_delay -clock clk -max 1.500 [get_ports {mb_start intra_mode* qp* p* top_* left_*}]
set_input_delay -clock clk -min 0.300 [get_ports {mb_start intra_mode* qp* p* top_* left_*}]

# Output Delays (30% of clock period budget)
set_output_delay -clock clk -max 1.500 [get_ports {mb_busy mb_done cur_blk_idx* stream_* block_done}]
set_output_delay -clock clk -min 0.200 [get_ports {mb_busy mb_done cur_blk_idx* stream_* block_done}]

# Environmental Constraints & Driving Cells
set_driving_cell -lib_cell INVX4 [get_ports {mb_start intra_mode* qp* p* top_* left_*}]
set_load -pin_load 0.025 [get_ports {mb_busy mb_done cur_blk_idx* stream_* block_done}]
