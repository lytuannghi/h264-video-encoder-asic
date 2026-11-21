// =============================================================================
// File: h264_macroblock_ctrl.v
// Module: h264_macroblock_ctrl
// Project: H.264/AVC Real-Time Video Compression Engine
// Description: 16x16 Macroblock Controller orchestrating raster scan of 16 4x4
//              sub-blocks, intra prediction coordination, neighbor buffer management,
//              and pipeline handshake for real-time video encoding.
// =============================================================================

`timescale 1ns / 1ps

module h264_macroblock_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        mb_start,
    input  wire [1:0]  mb_intra_mode, // 0: Vert, 1: Horiz, 2: DC
    input  wire [5:0]  mb_qp,

    // Block pipeline handshakes
    output reg         blk_start,
    output reg  [3:0]  blk_idx,       // 0 to 15 (sub-blocks in 16x16 MB)
    output reg  [1:0]  blk_pred_mode,
    output reg  [5:0]  blk_qp,

    input  wire        blk_done,
    output reg         mb_done,
    output reg         mb_busy
);

    // FSM States
    localparam MB_IDLE     = 2'd0;
    localparam MB_RUN_BLK  = 2'd1;
    localparam MB_WAIT_BLK = 2'd2;
    localparam MB_COMPLETE = 2'd3;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= MB_IDLE;
            blk_start     <= 1'b0;
            blk_idx       <= 4'd0;
            blk_pred_mode <= 2'd0;
            blk_qp        <= 6'd26;
            mb_done       <= 1'b0;
            mb_busy       <= 1'b0;
        end else begin
            blk_start <= 1'b0;
            mb_done   <= 1'b0;

            case (state)
                MB_IDLE: begin
                    mb_busy <= 1'b0;
                    if (mb_start) begin
                        mb_busy       <= 1'b1;
                        blk_idx       <= 4'd0;
                        blk_pred_mode <= mb_intra_mode;
                        blk_qp        <= mb_qp;
                        state         <= MB_RUN_BLK;
                    end
                end

                MB_RUN_BLK: begin
                    blk_start <= 1'b1;
                    state     <= MB_WAIT_BLK;
                end

                MB_WAIT_BLK: begin
                    if (blk_done) begin
                        if (blk_idx == 4'd15) begin
                            state <= MB_COMPLETE;
                        end else begin
                            blk_idx <= blk_idx + 4'd1;
                            state   <= MB_RUN_BLK;
                        end
                    end
                end

                MB_COMPLETE: begin
                    mb_done <= 1'b1;
                    mb_busy <= 1'b0;
                    state   <= MB_IDLE;
                end
            endcase
        end
    end

endmodule
