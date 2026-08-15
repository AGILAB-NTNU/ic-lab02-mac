// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/13 11:36:46
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic-lab02-mac
// Module Name: sync_fifo
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立標準同步 FIFO (Synchronous FIFO)，作為 input A, B 以及 output sum 的緩衝器。
// Coding Rules:
//   Type       : RTL (Synthesizable Circuit)
//   SV Syntax  : Avoid new SystemVerilog syntax; keep it synthesizable and compatible.RTL (Synthesizable Circuit)
//   Ports      : i_* = inputs, o_* = outputs (e.g. i_clk, i_rst_n, i_a, i_b, o_y)
//   Regs       : *_r = registers, *_next = combinational next-state signals
//   Reset      : active-low synchronous reset (i_rst_n), posedge i_clk only
//   FSM        : strict 3-block style; assign defaults in always_comb; no latches
//   Handshake  : *_vld / *_rdy naming
//   Systolic   : u_PE_R[r]_C[c], pe_data_east/south, *_ping / *_pong
//   Safety     : avoid bit-width mismatches
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
// verilog_lint: waive-stop

module sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 16
) (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_wr_en,
    input wire [DATA_WIDTH-1:0] i_wr_data,
    input wire i_rd_en,
    output reg [DATA_WIDTH-1:0] o_rd_data_r,
    output wire o_full,  // 1 when FIFO is completely o_full
    output wire o_empty  // 1 when FIFO is completely o_empty
);
    localparam integer Addrwidth = $clog2(DEPTH);
    localparam integer Countwidth = $clog2(DEPTH+1);
    reg [DATA_WIDTH-1:0] memory_r [DEPTH];
    reg [Addrwidth-1:0] wr_ptr_r;
    reg [Addrwidth-1:0] rd_ptr_r;
    reg [Countwidth-1:0] count_r;

    wire wr_accept;
    wire rd_accept;

    assign o_full = (count_r == DEPTH);
    assign o_empty = (count_r == 0);
    assign wr_accept = (!o_full && i_wr_en);
    assign rd_accept = (!o_empty && i_rd_en);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            wr_ptr_r <= 0;
        end
        else if (wr_accept) begin
            memory_r[wr_ptr_r] <= i_wr_data;

            if (wr_ptr_r == DEPTH-1)
                wr_ptr_r <= 0;
            else
                wr_ptr_r <= wr_ptr_r + 1'b1;
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rd_ptr_r <= 0;
            o_rd_data_r <= 0;
        end
        else if (rd_accept) begin
            o_rd_data_r <= memory_r[rd_ptr_r];

            if (rd_ptr_r == DEPTH-1)
                rd_ptr_r <= 0;
            else
                rd_ptr_r <= rd_ptr_r + 1'b1;
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            count_r <= 0;
        end
        else begin
            case ({wr_accept, rd_accept})
                2'b10: count_r <= count_r + 1'b1; // Write accepted, increment count
                2'b01: count_r <= count_r - 1'b1; // Read accepted, decrement count
                default: count_r <= count_r;      // No change in count
            endcase
        end
    end

endmodule
