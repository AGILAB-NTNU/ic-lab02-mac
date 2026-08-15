// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/14 13:58:33
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic-lab02-mac
// Module Name: mac_accum
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立乘法累加器（MAC）模組
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

module mac_accum #(
    parameter integer A_W   = 8,
    parameter integer B_W   = 8,
    parameter integer ACC_W = 32
) (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_acc_en,
    input wire i_acc_clr,
    input wire [A_W-1:0] i_A_data,  // Data from A FIFO.
    input wire [B_W-1:0] i_B_data,  // Data from B FIFO.

    output reg [ACC_W-1:0] o_acc_sum_r  // Result after doing ACC.
);

    // 8 bits x 8 bits Multiplier, Result is about 16 bits.
    wire [A_W+B_W-1:0] mult_result;

    assign mult_result = i_A_data * i_B_data;

    // 將乘法結果零延伸至 Accumulator 的位元寬度，方便相加
    wire [ACC_W-1:0] mult_ext = {{(ACC_W-(A_W+B_W)){1'b0}}, mult_result};

    // MAC logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_acc_sum_r <= {ACC_W{1'b0}};
        end else if (i_acc_clr && i_acc_en) begin
            // 清零的同時累加本筆資料 (新區塊的第一筆)
            o_acc_sum_r <= mult_ext;
        end else if (i_acc_clr) begin
            // 單純清零
            o_acc_sum_r <= {ACC_W{1'b0}};
        end else if (i_acc_en) begin
            // 正常累加
            o_acc_sum_r <= o_acc_sum_r + mult_ext;
        end else begin
            // 兩者皆為 0，保持
            o_acc_sum_r <= o_acc_sum_r;
        end
    end

endmodule
