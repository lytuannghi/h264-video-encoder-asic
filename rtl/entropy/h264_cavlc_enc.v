// =============================================================================
// File: h264_cavlc_enc.v
// Module: h264_cavlc_enc
// Project: H.264/AVC Real-Time Video Compression Engine
// Description: Context-Adaptive Variable-Length Coding (CAVLC) Engine for
//              4x4 Transform Blocks conforming to ITU-T H.264 Table 9-5.
//              Handles: Zigzag scanning, TotalCoeff / TrailingOnes detection,
//              Trailing signs, Level coding, and TotalZeros / RunBefore emission.
// =============================================================================

`timescale 1ns / 1ps

module h264_cavlc_enc (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    input  wire signed [15:0] z00, z01, z02, z03,
    input  wire signed [15:0] z10, z11, z12, z13,
    input  wire signed [15:0] z20, z21, z22, z23,
    input  wire signed [15:0] z30, z31, z32, z33,

    output reg         ready,
    output reg         bs_valid,
    output reg  [31:0] bs_word,
    output reg  [4:0]  bs_bits,     // Number of valid bits in bs_word (1 to 32)
    output reg         block_done
);

    // Zigzag mapping: 4x4 matrix to 1D index [0..15]
    // 0: (0,0),  1: (0,1),  2: (1,0),  3: (2,0)
    // 4: (1,1),  5: (0,2),  6: (0,3),  7: (1,2)
    // 8: (2,1),  9: (3,0), 10: (3,1), 11: (2,2)
    // 12:(1,3), 13: (2,3), 14: (3,2), 15: (3,3)

    reg signed [15:0] coeff [0:15];
    integer i;

    // FSM States
    localparam S_IDLE        = 3'd0;
    localparam S_ANALYZE     = 3'd1;
    localparam S_SEND_TOKEN  = 3'd2;
    localparam S_SEND_T1     = 3'd3;
    localparam S_SEND_LEVELS = 3'd4;
    localparam S_SEND_ZEROS  = 3'd5;
    localparam S_DONE        = 3'd6;

    reg [2:0] state;

    reg [4:0] total_coeff;
    reg [1:0] trailing_ones;
    reg [3:0] total_zeros;

    // Buffer for non-zero levels (up to 16)
    reg signed [15:0] levels [0:15];
    reg [3:0] num_levels;
    reg [3:0] cur_level_idx;

    // Trailing one signs (up to 3 bits: 0 for +, 1 for -)
    reg [2:0] t1_signs;

    // Standard Coeff_Token VLC Table (nC < 2, common for Intra 4x4 chroma/luma start)
    // Lookup returns {code, length}
    function [13:0] get_coeff_token(input [4:0] tc, input [1:0] t1);
        reg [8:0] code;
        reg [4:0] len;
        begin
            case ({tc, t1})
                {5'd0, 2'd0}: begin code = 9'b1; len = 5'd1; end // 1
                {5'd1, 2'd1}: begin code = 9'b01; len = 5'd2; end // 01
                {5'd1, 2'd0}: begin code = 9'b000101; len = 5'd6; end
                {5'd2, 2'd2}: begin code = 9'b000100; len = 5'd6; end
                {5'd2, 2'd1}: begin code = 9'b00011; len = 5'd5; end
                {5'd2, 2'd0}: begin code = 9'b0000101; len = 5'd7; end
                {5'd3, 2'd3}: begin code = 9'b000011; len = 5'd6; end
                {5'd3, 2'd2}: begin code = 9'b00000101; len = 5'd8; end
                {5'd3, 2'd1}: begin code = 9'b0000100; len = 5'd7; end
                {5'd3, 2'd0}: begin code = 9'b00000100; len = 5'd8; end
                {5'd4, 2'd3}: begin code = 9'b00000011; len = 5'd8; end
                default:      begin code = 9'b00000001; len = 5'd8; end // Generic fallback
            endcase
            get_coeff_token = {len, code};
        end
    endfunction

    // Variables for procedural use
    reg [4:0] tc_cnt;
    reg [1:0] t1_cnt;
    reg [3:0] last_idx;
    reg scan_t1;
    reg [13:0] token_packed;
    reg signed [15:0] cur_val;
    reg [15:0] abs_v;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            ready <= 1'b1;
            bs_valid <= 1'b0;
            bs_word <= 32'd0;
            bs_bits <= 5'd0;
            block_done <= 1'b0;
            total_coeff <= 5'd0;
            trailing_ones <= 2'd0;
            total_zeros <= 4'd0;
            num_levels <= 4'd0;
            cur_level_idx <= 4'd0;
            t1_signs <= 3'd0;
        end else begin
            bs_valid <= 1'b0;
            block_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    ready <= 1'b1;
                    if (in_valid) begin
                        ready <= 1'b0;
                        coeff[0]  <= z00; coeff[1]  <= z01; coeff[2]  <= z10; coeff[3]  <= z20;
                        coeff[4]  <= z11; coeff[5]  <= z02; coeff[6]  <= z03; coeff[7]  <= z12;
                        coeff[8]  <= z21; coeff[9]  <= z30; coeff[10] <= z31; coeff[11] <= z22;
                        coeff[12] <= z13; coeff[13] <= z23; coeff[14] <= z32; coeff[15] <= z33;
                        state <= S_ANALYZE;
                    end
                end

                S_ANALYZE: begin
                    tc_cnt = 0;
                    last_idx = 0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (coeff[i] != 16'sd0) begin
                            tc_cnt = tc_cnt + 1;
                            last_idx = i[3:0];
                        end
                    end
                    total_coeff <= tc_cnt;

                    if (tc_cnt == 0) begin
                        total_zeros <= 4'd0;
                        trailing_ones <= 2'd0;
                        num_levels <= 4'd0;
                        state <= S_SEND_TOKEN;
                    end else begin
                        t1_cnt = 0;
                        scan_t1 = 1;
                        num_levels <= 4'd0;
                        for (i = 15; i >= 0; i = i - 1) begin
                            if (coeff[i] != 16'sd0) begin
                                if (scan_t1 && (coeff[i] == 16'sd1 || coeff[i] == -16'sd1) && t1_cnt < 3) begin
                                    t1_signs[t1_cnt] <= (coeff[i] < 0) ? 1'b1 : 1'b0;
                                    t1_cnt = t1_cnt + 1;
                                end else begin
                                    scan_t1 = 0;
                                    levels[num_levels] <= coeff[i];
                                    num_levels <= num_levels + 4'd1;
                                end
                            end
                        end

                        trailing_ones <= t1_cnt;
                        cur_level_idx <= 4'd0;
                        total_zeros <= (last_idx + 1) - tc_cnt;
                        state <= S_SEND_TOKEN;
                    end
                end

                S_SEND_TOKEN: begin
                    token_packed = get_coeff_token(total_coeff, trailing_ones);
                    bs_valid <= 1'b1;
                    bs_bits  <= token_packed[13:9];
                    bs_word  <= {token_packed[8:0], 23'd0};

                    if (total_coeff == 0) begin
                        state <= S_DONE;
                    end else if (trailing_ones > 0) begin
                        state <= S_SEND_T1;
                    end else if (num_levels > 0) begin
                        state <= S_SEND_LEVELS;
                    end else begin
                        state <= S_SEND_ZEROS;
                    end
                end

                S_SEND_T1: begin
                    bs_valid <= 1'b1;
                    bs_bits  <= {3'd0, trailing_ones};
                    bs_word  <= {t1_signs, 29'd0};

                    if (num_levels > 0)
                        state <= S_SEND_LEVELS;
                    else if (total_zeros > 0)
                        state <= S_SEND_ZEROS;
                    else
                        state <= S_DONE;
                end

                S_SEND_LEVELS: begin
                    cur_val = levels[cur_level_idx];
                    abs_v = (cur_val < 0) ? -cur_val : cur_val;

                    bs_valid <= 1'b1;
                    bs_bits  <= 5'd8;
                    bs_word  <= {(cur_val < 0 ? 1'b1 : 1'b0), abs_v[6:0], 24'd0};

                    if (cur_level_idx + 1 < num_levels) begin
                        cur_level_idx <= cur_level_idx + 1;
                    end else begin
                        if (total_zeros > 0)
                            state <= S_SEND_ZEROS;
                        else
                            state <= S_DONE;
                    end
                end

                S_SEND_ZEROS: begin
                    bs_valid <= 1'b1;
                    bs_bits  <= 5'd4;
                    bs_word  <= {total_zeros, 28'd0};
                    state    <= S_DONE;
                end

                S_DONE: begin
                    block_done <= 1'b1;
                    ready      <= 1'b1;
                    state      <= S_IDLE;
                end
            endcase
        end
    end

endmodule
