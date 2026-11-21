// =============================================================================
// File: intra_pred_4x4.v
// Module: intra_pred_4x4
// Project: H.264/AVC Real-Time Video Compression Engine
// Description: Intra 4x4 Spatial Prediction Engine implementing Mode 0 (Vertical),
//              Mode 1 (Horizontal), and Mode 2 (DC Prediction) conforming to
//              ITU-T H.264 / ISO/IEC 14496-10 standard.
// =============================================================================

`timescale 1ns / 1ps

module intra_pred_4x4 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [1:0]  pred_mode, // 2'b00: Vertical, 2'b01: Horizontal, 2'b10: DC

    // Boundary Neighboring Pixels (Top A..D, Left I..L)
    input  wire [7:0]  top_a, top_b, top_c, top_d,
    input  wire [7:0]  left_i, left_j, left_k, left_l,

    // Original 4x4 Pixel Block (16 pixels)
    input  wire [7:0]  orig_p00, orig_p01, orig_p02, orig_p03,
    input  wire [7:0]  orig_p10, orig_p11, orig_p12, orig_p13,
    input  wire [7:0]  orig_p20, orig_p21, orig_p22, orig_p23,
    input  wire [7:0]  orig_p30, orig_p31, orig_p32, orig_p33,

    // Residual Difference Block (D = Orig - Pred, 9-bit signed)
    output reg         res_valid,
    output reg  signed [8:0] res_d00, res_d01, res_d02, res_d03,
    output reg  signed [8:0] res_d10, res_d11, res_d12, res_d13,
    output reg  signed [8:0] res_d20, res_d21, res_d22, res_d23,
    output reg  signed [8:0] res_d30, res_d31, res_d32, res_d33
);

    // DC Average calculation: (A + B + C + D + I + J + K + L + 4) >> 3
    wire [11:0] sum_neighbors = top_a + top_b + top_c + top_d +
                                left_i + left_j + left_k + left_l;
    wire [7:0]  dc_val        = (sum_neighbors + 12'd4) >> 3;

    reg [7:0] pred [0:3][0:3];
    integer r, c;

    always @(*) begin
        case (pred_mode)
            2'b00: begin // Vertical: Copy Top pixels down columns
                pred[0][0] = top_a; pred[0][1] = top_b; pred[0][2] = top_c; pred[0][3] = top_d;
                pred[1][0] = top_a; pred[1][1] = top_b; pred[1][2] = top_c; pred[1][3] = top_d;
                pred[2][0] = top_a; pred[2][1] = top_b; pred[2][2] = top_c; pred[2][3] = top_d;
                pred[3][0] = top_a; pred[3][1] = top_b; pred[3][2] = top_c; pred[3][3] = top_d;
            end
            2'b01: begin // Horizontal: Copy Left pixels across rows
                pred[0][0] = left_i; pred[0][1] = left_i; pred[0][2] = left_i; pred[0][3] = left_i;
                pred[1][0] = left_j; pred[1][1] = left_j; pred[1][2] = left_j; pred[1][3] = left_j;
                pred[2][0] = left_k; pred[2][1] = left_k; pred[2][2] = left_k; pred[2][3] = left_k;
                pred[3][0] = left_l; pred[3][1] = left_l; pred[3][2] = left_l; pred[3][3] = left_l;
            end
            default: begin // DC Prediction (Mode 2)
                for (r = 0; r < 4; r = r + 1) begin
                    for (c = 0; c < 4; c = c + 1) begin
                        pred[r][c] = dc_val;
                    end
                end
            end
        endcase
    end

    // Compute Residual Difference: Original - Predicted
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res_valid <= 1'b0;
            res_d00 <= 9'sd0; res_d01 <= 9'sd0; res_d02 <= 9'sd0; res_d03 <= 9'sd0;
            res_d10 <= 9'sd0; res_d11 <= 9'sd0; res_d12 <= 9'sd0; res_d13 <= 9'sd0;
            res_d20 <= 9'sd0; res_d21 <= 9'sd0; res_d22 <= 9'sd0; res_d23 <= 9'sd0;
            res_d30 <= 9'sd0; res_d31 <= 9'sd0; res_d32 <= 9'sd0; res_d33 <= 9'sd0;
        end else if (start) begin
            res_valid <= 1'b1;
            res_d00 <= $signed({1'b0, orig_p00}) - $signed({1'b0, pred[0][0]});
            res_d01 <= $signed({1'b0, orig_p01}) - $signed({1'b0, pred[0][1]});
            res_d02 <= $signed({1'b0, orig_p02}) - $signed({1'b0, pred[0][2]});
            res_d03 <= $signed({1'b0, orig_p03}) - $signed({1'b0, pred[0][3]});

            res_d10 <= $signed({1'b0, orig_p10}) - $signed({1'b0, pred[1][0]});
            res_d11 <= $signed({1'b0, orig_p11}) - $signed({1'b0, pred[1][1]});
            res_d12 <= $signed({1'b0, orig_p12}) - $signed({1'b0, pred[1][2]});
            res_d13 <= $signed({1'b0, orig_p13}) - $signed({1'b0, pred[1][3]});

            res_d20 <= $signed({1'b0, orig_p20}) - $signed({1'b0, pred[2][0]});
            res_d21 <= $signed({1'b0, orig_p21}) - $signed({1'b0, pred[2][1]});
            res_d22 <= $signed({1'b0, orig_p22}) - $signed({1'b0, pred[2][2]});
            res_d23 <= $signed({1'b0, orig_p23}) - $signed({1'b0, pred[2][3]});

            res_d30 <= $signed({1'b0, orig_p30}) - $signed({1'b0, pred[3][0]});
            res_d31 <= $signed({1'b0, orig_p31}) - $signed({1'b0, pred[3][1]});
            res_d32 <= $signed({1'b0, orig_p32}) - $signed({1'b0, pred[3][2]});
            res_d33 <= $signed({1'b0, orig_p33}) - $signed({1'b0, pred[3][3]});
        end else begin
            res_valid <= 1'b0;
        end
    end

endmodule
