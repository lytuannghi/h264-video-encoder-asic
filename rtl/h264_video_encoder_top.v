// =============================================================================
// File: h264_video_encoder_top.v
// Module: h264_video_encoder_top
// Project: H.264/AVC Real-Time Video Compression Engine
// Description: Full-Flow Synthesizable Top-Level ASIC Video Encoder.
//              Integrates:
//              - Macroblock raster scan coordinator
//              - Intra 4x4 spatial prediction (Modes 0, 1, 2)
//              - 2D forward integer DCT transform (Chen-Malvar butterfly)
//              - Scaled integer quantizer (configurable QP 0..51)
//              - Context-Adaptive Variable-Length Coding (CAVLC) entropy encoder
//              - 32-bit streaming output bitstream packer
// =============================================================================

`timescale 1ns / 1ps

module h264_video_encoder_top (
    input  wire        clk,
    input  wire        rst_n,

    // Command Interface
    input  wire        mb_start,
    input  wire [1:0]  intra_mode,    // 0: Vertical, 1: Horizontal, 2: DC
    input  wire [5:0]  qp,            // Quantization parameter (0..51)
    output wire        mb_busy,
    output wire        mb_done,

    // Sub-block input pixels (16 pixels per 4x4 block)
    input  wire [7:0]  p00, p01, p02, p03,
    input  wire [7:0]  p10, p11, p12, p13,
    input  wire [7:0]  p20, p21, p22, p23,
    input  wire [7:0]  p30, p31, p32, p33,

    // Neighbor pixels for prediction
    input  wire [7:0]  top_a, top_b, top_c, top_d,
    input  wire [7:0]  left_i, left_j, left_k, left_l,

    // Current sub-block query
    output wire [3:0]  cur_blk_idx,

    // Output Compressed Bitstream Interface
    output wire        stream_valid,
    output wire [31:0] stream_data,
    output wire [4:0]  stream_bits,
    output wire        block_done
);

    // Macroblock Controller
    wire        blk_start;
    wire [3:0]  blk_idx;
    wire [1:0]  blk_pred_mode;
    wire [5:0]  blk_qp;
    wire        cavlc_block_done;

    assign cur_blk_idx = blk_idx;

    h264_macroblock_ctrl u_mb_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .mb_start      (mb_start),
        .mb_intra_mode (intra_mode),
        .mb_qp         (qp),
        .blk_start     (blk_start),
        .blk_idx       (blk_idx),
        .blk_pred_mode (blk_pred_mode),
        .blk_qp        (blk_qp),
        .blk_done      (cavlc_block_done),
        .mb_done       (mb_done),
        .mb_busy       (mb_busy)
    );

    // Intra 4x4 Prediction Engine
    wire res_valid;
    wire signed [8:0] d00, d01, d02, d03;
    wire signed [8:0] d10, d11, d12, d13;
    wire signed [8:0] d20, d21, d22, d23;
    wire signed [8:0] d30, d31, d32, d33;

    intra_pred_4x4 u_intra_pred (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (blk_start),
        .pred_mode (blk_pred_mode),
        .top_a     (top_a),
        .top_b     (top_b),
        .top_c     (top_c),
        .top_d     (top_d),
        .left_i    (left_i),
        .left_j    (left_j),
        .left_k    (left_k),
        .left_l    (left_l),
        .orig_p00  (p00), .orig_p01 (p01), .orig_p02 (p02), .orig_p03 (p03),
        .orig_p10  (p10), .orig_p11 (p11), .orig_p12 (p12), .orig_p13 (p13),
        .orig_p20  (p20), .orig_p21 (p21), .orig_p22 (p22), .orig_p23 (p23),
        .orig_p30  (p30), .orig_p31 (p31), .orig_p32 (p32), .orig_p33 (p33),
        .res_valid (res_valid),
        .res_d00   (d00), .res_d01 (d01), .res_d02 (d02), .res_d03 (d03),
        .res_d10   (d10), .res_d11 (d11), .res_d12 (d12), .res_d13 (d13),
        .res_d20   (d20), .res_d21 (d21), .res_d22 (d22), .res_d23 (d23),
        .res_d30   (d30), .res_d31 (d31), .res_d32 (d32), .res_d33 (d33)
    );

    // 2D Forward Integer DCT Transform (Chen-Malvar 4x4)
    wire dct_valid;
    wire signed [15:0] w00, w01, w02, w03;
    wire signed [15:0] w10, w11, w12, w13;
    wire signed [15:0] w20, w21, w22, w23;
    wire signed [15:0] w30, w31, w32, w33;

    h264_dct_4x4 u_dct (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (res_valid),
        .d00       (d00), .d01 (d01), .d02 (d02), .d03 (d03),
        .d10       (d10), .d11 (d11), .d12 (d12), .d13 (d13),
        .d20       (d20), .d21 (d21), .d22 (d22), .d23 (d23),
        .d30       (d30), .d31 (d31), .d32 (d32), .d33 (d33),
        .out_valid (dct_valid),
        .w00       (w00), .w01 (w01), .w02 (w02), .w03 (w03),
        .w10       (w10), .w11 (w11), .w12 (w12), .w13 (w13),
        .w20       (w20), .w21 (w21), .w22 (w22), .w23 (w23),
        .w30       (w30), .w31 (w31), .w32 (w32), .w33 (w33)
    );

    // Scaled Integer Quantizer
    wire quant_valid;
    wire signed [15:0] z00, z01, z02, z03;
    wire signed [15:0] z10, z11, z12, z13;
    wire signed [15:0] z20, z21, z22, z23;
    wire signed [15:0] z30, z31, z32, z33;

    h264_quantizer u_quant (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (dct_valid),
        .qp        (blk_qp),
        .w00       (w00), .w01 (w01), .w02 (w02), .w03 (w03),
        .w10       (w10), .w11 (w11), .w12 (w12), .w13 (w13),
        .w20       (w20), .w21 (w21), .w22 (w22), .w23 (w23),
        .w30       (w30), .w31 (w31), .w32 (w32), .w33 (w33),
        .out_valid (quant_valid),
        .z00       (z00), .z01 (z01), .z02 (z02), .z03 (z03),
        .z10       (z10), .z11 (z11), .z12 (z12), .z13 (z13),
        .z20       (z20), .z21 (z21), .z22 (z22), .z23 (z23),
        .z30       (z30), .z31 (z31), .z32 (z32), .z33 (z33)
    );

    // CAVLC Entropy Encoder
    wire cavlc_ready;
    wire cavlc_bs_valid;
    wire [31:0] cavlc_bs_word;
    wire [4:0]  cavlc_bs_bits;

    h264_cavlc_enc u_cavlc (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (quant_valid),
        .z00        (z00), .z01 (z01), .z02 (z02), .z03 (z03),
        .z10        (z10), .z11 (z11), .z12 (z12), .z13 (z13),
        .z20        (z20), .z21 (z21), .z22 (z22), .z23 (z23),
        .z30        (z30), .z31 (z31), .z32 (z32), .z33 (z33),
        .ready      (cavlc_ready),
        .bs_valid   (cavlc_bs_valid),
        .bs_word    (cavlc_bs_word),
        .bs_bits    (cavlc_bs_bits),
        .block_done (cavlc_block_done)
    );

    assign stream_valid = cavlc_bs_valid;
    assign stream_data  = cavlc_bs_word;
    assign stream_bits  = cavlc_bs_bits;
    assign block_done   = cavlc_block_done;

endmodule
