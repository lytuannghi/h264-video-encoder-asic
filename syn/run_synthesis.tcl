# =============================================================================
# Synthesis Script: run_synthesis.tcl
# Tool: Synopsys Design Compiler / Cadence Genus
# =============================================================================

set TOP_MODULE h264_video_encoder_top

set RTL_FILES [list \
    ../rtl/intra/intra_pred_4x4.v \
    ../rtl/transform/h264_dct_4x4.v \
    ../rtl/quant/h264_quantizer.v \
    ../rtl/entropy/h264_cavlc_enc.v \
    ../rtl/top/h264_macroblock_ctrl.v \
    ../rtl/h264_video_encoder_top.v \
]

read_verilog $RTL_FILES
current_design $TOP_MODULE
link

source h264_timing.sdc

compile_ultra -gate_clock -no_autoungroup

report_timing -delay max -max_paths 10 > reports/timing_report.txt
report_area -hierarchy > reports/area_report.txt
report_power > reports/power_report.txt

write -format verilog -hierarchy -output netlist/${TOP_MODULE}_syn.v
