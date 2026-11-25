// =============================================================================
// File: h264_quantizer.v
// Module: h264_quantizer
// Project: H.264/AVC Real-Time Video Compression Engine
// Description: Scaled Integer Quantizer for 4x4 DCT blocks conforming to H.264 standard.
//              Z_ij = sign(W_ij) * ((|W_ij| * MF + f) >> qbits)
//              qbits = 15 + (QP / 6)
//              f = 2^qbits / 3 for Intra blocks
// =============================================================================

`timescale 1ns / 1ps

module h264_quantizer (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    input  wire [5:0]  qp, // Quantization Parameter (0 to 51)

    // 16 DCT coefficients (16-bit signed)
    input  wire signed [15:0] w00, w01, w02, w03,
    input  wire signed [15:0] w10, w11, w12, w13,
    input  wire signed [15:0] w20, w21, w22, w23,
    input  wire signed [15:0] w30, w31, w32, w33,

    output reg         out_valid,
    // 16 Quantized coefficients (16-bit signed, standard range typically -2048 to +2047)
    output reg  signed [15:0] z00, z01, z02, z03,
    output reg  signed [15:0] z10, z11, z12, z13,
    output reg  signed [15:0] z20, z21, z22, z23,
    output reg  signed [15:0] z30, z31, z32, z33
);

    reg  [2:0] qp_rem;
    reg  [3:0] qp_per;
    always @(*) begin
        case (qp)
            6'd0:  begin qp_per = 4'd0; qp_rem = 3'd0; end
            6'd1:  begin qp_per = 4'd0; qp_rem = 3'd1; end
            6'd2:  begin qp_per = 4'd0; qp_rem = 3'd2; end
            6'd3:  begin qp_per = 4'd0; qp_rem = 3'd3; end
            6'd4:  begin qp_per = 4'd0; qp_rem = 3'd4; end
            6'd5:  begin qp_per = 4'd0; qp_rem = 3'd5; end
            6'd6:  begin qp_per = 4'd1; qp_rem = 3'd0; end
            6'd7:  begin qp_per = 4'd1; qp_rem = 3'd1; end
            6'd8:  begin qp_per = 4'd1; qp_rem = 3'd2; end
            6'd9:  begin qp_per = 4'd1; qp_rem = 3'd3; end
            6'd10: begin qp_per = 4'd1; qp_rem = 3'd4; end
            6'd11: begin qp_per = 4'd1; qp_rem = 3'd5; end
            6'd12: begin qp_per = 4'd2; qp_rem = 3'd0; end
            6'd13: begin qp_per = 4'd2; qp_rem = 3'd1; end
            6'd14: begin qp_per = 4'd2; qp_rem = 3'd2; end
            6'd15: begin qp_per = 4'd2; qp_rem = 3'd3; end
            6'd16: begin qp_per = 4'd2; qp_rem = 3'd4; end
            6'd17: begin qp_per = 4'd2; qp_rem = 3'd5; end
            6'd18: begin qp_per = 4'd3; qp_rem = 3'd0; end
            6'd19: begin qp_per = 4'd3; qp_rem = 3'd1; end
            6'd20: begin qp_per = 4'd3; qp_rem = 3'd2; end
            6'd21: begin qp_per = 4'd3; qp_rem = 3'd3; end
            6'd22: begin qp_per = 4'd3; qp_rem = 3'd4; end
            6'd23: begin qp_per = 4'd3; qp_rem = 3'd5; end
            6'd24: begin qp_per = 4'd4; qp_rem = 3'd0; end
            6'd25: begin qp_per = 4'd4; qp_rem = 3'd1; end
            6'd26: begin qp_per = 4'd4; qp_rem = 3'd2; end
            6'd27: begin qp_per = 4'd4; qp_rem = 3'd3; end
            6'd28: begin qp_per = 4'd4; qp_rem = 3'd4; end
            6'd29: begin qp_per = 4'd4; qp_rem = 3'd5; end
            6'd30: begin qp_per = 4'd5; qp_rem = 3'd0; end
            6'd31: begin qp_per = 4'd5; qp_rem = 3'd1; end
            6'd32: begin qp_per = 4'd5; qp_rem = 3'd2; end
            6'd33: begin qp_per = 4'd5; qp_rem = 3'd3; end
            6'd34: begin qp_per = 4'd5; qp_rem = 3'd4; end
            6'd35: begin qp_per = 4'd5; qp_rem = 3'd5; end
            6'd36: begin qp_per = 4'd6; qp_rem = 3'd0; end
            6'd37: begin qp_per = 4'd6; qp_rem = 3'd1; end
            6'd38: begin qp_per = 4'd6; qp_rem = 3'd2; end
            6'd39: begin qp_per = 4'd6; qp_rem = 3'd3; end
            6'd40: begin qp_per = 4'd6; qp_rem = 3'd4; end
            6'd41: begin qp_per = 4'd6; qp_rem = 3'd5; end
            6'd42: begin qp_per = 4'd7; qp_rem = 3'd0; end
            6'd43: begin qp_per = 4'd7; qp_rem = 3'd1; end
            6'd44: begin qp_per = 4'd7; qp_rem = 3'd2; end
            6'd45: begin qp_per = 4'd7; qp_rem = 3'd3; end
            6'd46: begin qp_per = 4'd7; qp_rem = 3'd4; end
            6'd47: begin qp_per = 4'd7; qp_rem = 3'd5; end
            6'd48: begin qp_per = 4'd8; qp_rem = 3'd0; end
            6'd49: begin qp_per = 4'd8; qp_rem = 3'd1; end
            6'd50: begin qp_per = 4'd8; qp_rem = 3'd2; end
            default: begin qp_per = 4'd8; qp_rem = 3'd3; end
        endcase
    end
    wire [4:0] qbits  = 5'd15 + qp_per; // 15 to 23

    // Multiplication factor lookup
    reg [13:0] mf_pos0; // (0,0), (0,2), (2,0), (2,2)
    reg [12:0] mf_pos1; // (1,1), (1,3), (3,1), (3,3)
    reg [13:0] mf_pos2; // all other positions

    always @(*) begin
        case (qp_rem)
            3'd0: begin mf_pos0 = 14'd13107; mf_pos1 = 13'd5243; mf_pos2 = 14'd8066; end
            3'd1: begin mf_pos0 = 14'd11916; mf_pos1 = 13'd4660; mf_pos2 = 14'd7490; end
            3'd2: begin mf_pos0 = 14'd10082; mf_pos1 = 13'd4194; mf_pos2 = 14'd6554; end
            3'd3: begin mf_pos0 = 14'd9362;  mf_pos1 = 13'd3647; mf_pos2 = 14'd5825; end
            3'd4: begin mf_pos0 = 14'd8192;  mf_pos1 = 13'd3355; mf_pos2 = 14'd5243; end
            default: begin mf_pos0 = 14'd7282; mf_pos1 = 13'd2893; mf_pos2 = 14'd4559; end
        endcase
    end

    // Rounding offset f = (1 << qbits) / 3
    // For qbits in 15..23:
    reg [23:0] f_offset;
    always @(*) begin
        case (qbits)
            5'd15: f_offset = 24'd10922;      // 32768 / 3
            5'd16: f_offset = 24'd21845;      // 65536 / 3
            5'd17: f_offset = 24'd43690;
            5'd18: f_offset = 24'd87381;
            5'd19: f_offset = 24'd174762;
            5'd20: f_offset = 24'd349525;
            5'd21: f_offset = 24'd699050;
            5'd22: f_offset = 24'd1398101;
            default: f_offset = 24'd2796202; // qbits = 23
        endcase
    end

    // Quantize single element function
    function signed [15:0] quant_val(
        input signed [15:0] w,
        input [13:0]        mf,
        input [4:0]         qb,
        input [23:0]        offset
    );
        reg [15:0] abs_w;
        reg [31:0] prod;
        reg [31:0] scaled;
        reg [15:0] mag;
        begin
            if (w < 0)
                abs_w = -w;
            else
                abs_w = w;

            prod = abs_w * mf;
            scaled = prod + offset;
            mag = scaled >> qb;

            if (w < 0)
                quant_val = -mag;
            else
                quant_val = mag;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            z00 <= 16'd0; z01 <= 16'd0; z02 <= 16'd0; z03 <= 16'd0;
            z10 <= 16'd0; z11 <= 16'd0; z12 <= 16'd0; z13 <= 16'd0;
            z20 <= 16'd0; z21 <= 16'd0; z22 <= 16'd0; z23 <= 16'd0;
            z30 <= 16'd0; z31 <= 16'd0; z32 <= 16'd0; z33 <= 16'd0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                z00 <= quant_val(w00, mf_pos0, qbits, f_offset);
                z01 <= quant_val(w01, mf_pos2, qbits, f_offset);
                z02 <= quant_val(w02, mf_pos0, qbits, f_offset);
                z03 <= quant_val(w03, mf_pos2, qbits, f_offset);

                z10 <= quant_val(w10, mf_pos2, qbits, f_offset);
                z11 <= quant_val(w11, mf_pos1, qbits, f_offset);
                z12 <= quant_val(w12, mf_pos2, qbits, f_offset);
                z13 <= quant_val(w13, mf_pos1, qbits, f_offset);

                z20 <= quant_val(w20, mf_pos0, qbits, f_offset);
                z21 <= quant_val(w21, mf_pos2, qbits, f_offset);
                z22 <= quant_val(w22, mf_pos0, qbits, f_offset);
                z23 <= quant_val(w23, mf_pos2, qbits, f_offset);

                z30 <= quant_val(w30, mf_pos2, qbits, f_offset);
                z31 <= quant_val(w31, mf_pos1, qbits, f_offset);
                z32 <= quant_val(w32, mf_pos2, qbits, f_offset);
                z33 <= quant_val(w33, mf_pos1, qbits, f_offset);
            end
        end
    end

endmodule
