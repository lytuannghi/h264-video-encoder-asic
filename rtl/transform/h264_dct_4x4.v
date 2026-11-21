// =============================================================================
// File: h264_dct_4x4.v
// Module: h264_dct_4x4
// Project: H.264/AVC Real-Time Video Compression Engine
// Description: 2D Forward Integer Discrete Cosine Transform (FDCT 4x4)
//              using Chen-Malvar integer butterfly matrix (zero multipliers).
//              W = C * D * C^T
// =============================================================================

`timescale 1ns / 1ps

module h264_dct_4x4 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    input  wire signed [8:0] d00, d01, d02, d03,
    input  wire signed [8:0] d10, d11, d12, d13,
    input  wire signed [8:0] d20, d21, d22, d23,
    input  wire signed [8:0] d30, d31, d32, d33,

    output reg         out_valid,
    output reg  signed [15:0] w00, w01, w02, w03,
    output reg  signed [15:0] w10, w11, w12, w13,
    output reg  signed [15:0] w20, w21, w22, w23,
    output reg  signed [15:0] w30, w31, w32, w33
);

    // 1D Transform Task: converts [x0, x1, x2, x3] -> [y0, y1, y2, y3]
    function [63:0] transform_1d(input signed [15:0] x0, x1, x2, x3);
        reg signed [15:0] e0, e1, e2, e3;
        reg signed [15:0] y0, y1, y2, y3;
        begin
            e0 = x0 + x3;
            e1 = x1 + x2;
            e2 = x1 - x2;
            e3 = x0 - x3;

            y0 = e0 + e1;
            y1 = (e3 <<< 1) + e2;
            y2 = e0 - e1;
            y3 = e3 - (e2 <<< 1);

            transform_1d = {y3, y2, y1, y0};
        end
    endfunction

    // Stage 1: Row Transform
    reg signed [15:0] m00, m01, m02, m03;
    reg signed [15:0] m10, m11, m12, m13;
    reg signed [15:0] m20, m21, m22, m23;
    reg signed [15:0] m30, m31, m32, m33;
    reg stage1_valid;

    wire [63:0] row0 = transform_1d({{7{d00[8]}}, d00}, {{7{d01[8]}}, d01}, {{7{d02[8]}}, d02}, {{7{d03[8]}}, d03});
    wire [63:0] row1 = transform_1d({{7{d10[8]}}, d10}, {{7{d11[8]}}, d11}, {{7{d12[8]}}, d12}, {{7{d13[8]}}, d13});
    wire [63:0] row2 = transform_1d({{7{d20[8]}}, d20}, {{7{d21[8]}}, d21}, {{7{d22[8]}}, d22}, {{7{d23[8]}}, d23});
    wire [63:0] row3 = transform_1d({{7{d30[8]}}, d30}, {{7{d31[8]}}, d31}, {{7{d32[8]}}, d32}, {{7{d33[8]}}, d33});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
            m00 <= 16'sd0; m01 <= 16'sd0; m02 <= 16'sd0; m03 <= 16'sd0;
            m10 <= 16'sd0; m11 <= 16'sd0; m12 <= 16'sd0; m13 <= 16'sd0;
            m20 <= 16'sd0; m21 <= 16'sd0; m22 <= 16'sd0; m23 <= 16'sd0;
            m30 <= 16'sd0; m31 <= 16'sd0; m32 <= 16'sd0; m33 <= 16'sd0;
        end else if (in_valid) begin
            stage1_valid <= 1'b1;
            {m03, m02, m01, m00} <= row0;
            {m13, m12, m11, m10} <= row1;
            {m23, m22, m21, m20} <= row2;
            {m33, m32, m31, m30} <= row3;
        end else begin
            stage1_valid <= 1'b0;
        end
    end

    // Stage 2: Column Transform
    wire [63:0] col0 = transform_1d(m00, m10, m20, m30);
    wire [63:0] col1 = transform_1d(m01, m11, m21, m31);
    wire [63:0] col2 = transform_1d(m02, m12, m22, m32);
    wire [63:0] col3 = transform_1d(m03, m13, m23, m33);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            w00 <= 16'sd0; w01 <= 16'sd0; w02 <= 16'sd0; w03 <= 16'sd0;
            w10 <= 16'sd0; w11 <= 16'sd0; w12 <= 16'sd0; w13 <= 16'sd0;
            w20 <= 16'sd0; w21 <= 16'sd0; w22 <= 16'sd0; w23 <= 16'sd0;
            w30 <= 16'sd0; w31 <= 16'sd0; w32 <= 16'sd0; w33 <= 16'sd0;
        end else if (stage1_valid) begin
            out_valid <= 1'b1;
            {w30, w20, w10, w00} <= col0;
            {w31, w21, w11, w01} <= col1;
            {w32, w22, w12, w02} <= col2;
            {w33, w23, w13, w03} <= col3;
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
