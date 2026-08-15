// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/14 13:48:12
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic-lab02-mac
// Module Name: mac_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立 top module，連接控制單元 FSM 和運算單元 Datapath
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

module mac_top #(
    parameter integer N = 10,           // 每個區塊累加次數
    parameter integer DATA_W = 8,       // A/B 資料位元寬度
    parameter integer ACC_W = 32,       // 累加結果位元寬度
    parameter integer FIFO_DEPTH = 16,  // A/B FIFO 深度
    parameter integer SUM_DEPTH = 16     // Sum FIFO 深度
) (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_en,

    //  A FIFO 寫入介面 (外部 Producer)
    input wire i_wr_en_a,
    input wire [DATA_W-1:0] i_a_wdata,
    output wire o_fifo_a_full,

    // B FIFO 寫入介面 (外部 Producer)
    input wire i_wr_en_b,
    input wire [DATA_W-1:0] i_b_wdata,
    output wire o_fifo_b_full,

    // Sum FIFO 讀取介面 (外部 Consumer)
    input wire i_rd_en_sum,
    output wire [ACC_W-1:0] o_sum_data,
    output wire o_fifo_sum_empty,

    // 除錯用觀察訊號 (可選，方便 Testbench 觀察內部狀態)
    output wire o_dbg_rd_en,
    output wire o_dbg_acc_en,
    output wire o_dbg_acc_clr,
    output wire o_dbg_sum_wr_en
);

    // 內部連接訊號
    wire fifo_a_empty, fifo_b_empty, fifo_sum_full;
    wire rd_en, acc_en, acc_clr, sum_wr_en;
    wire [DATA_W-1:0] a_dout, b_dout;
    wire [ACC_W-1:0] acc_sum;

    assign o_dbg_rd_en     = rd_en;
    assign o_dbg_acc_en    = acc_en;
    assign o_dbg_acc_clr   = acc_clr;
    assign o_dbg_sum_wr_en = sum_wr_en;

    // A FIFO
    sync_fifo #(
        .DATA_WIDTH   (DATA_W),
        .DEPTH        (FIFO_DEPTH)
    ) u_fifo_a (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_wr_en      (i_wr_en_a),
        .i_wr_data    (i_a_wdata),
        .o_full       (o_fifo_a_full),
        .i_rd_en      (rd_en),
        .o_rd_data_r  (a_dout),
        .o_empty      (fifo_a_empty)
    );

    // B FIFO
    sync_fifo #(
        .DATA_WIDTH   (DATA_W),
        .DEPTH        (FIFO_DEPTH)
    ) u_fifo_b (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_wr_en      (i_wr_en_b),
        .i_wr_data    (i_b_wdata),
        .o_full       (o_fifo_b_full),
        .i_rd_en      (rd_en),
        .o_rd_data_r  (b_dout),
        .o_empty      (fifo_b_empty)
    );

    // FSM
    mac_control_fsm #(
        .N (N)
    ) u_ctrl (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),
        .i_en             (i_en),
        .i_fifo_A_empty   (fifo_a_empty),
        .i_fifo_B_empty   (fifo_b_empty),
        .i_fifo_sum_full  (fifo_sum_full),
        .o_rd_en          (rd_en),
        .o_acc_en         (acc_en),
        .o_acc_clr        (acc_clr),
        .o_sum_wr_en      (sum_wr_en)
    );

    // Datapath
    mac_accum #(
        .A_W          (DATA_W),
        .B_W          (DATA_W),
        .ACC_W        (ACC_W)
    ) u_acc (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_acc_en     (acc_en),
        .i_acc_clr    (acc_clr),
        .i_A_data     (a_dout),
        .i_B_data     (b_dout),
        .o_acc_sum_r  (acc_sum)
    );

    // Sum FIFO
    sync_fifo #(
        .DATA_WIDTH   (ACC_W),
        .DEPTH        (SUM_DEPTH)
    ) u_fifo_sum (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_wr_en      (sum_wr_en),
        .i_wr_data    (acc_sum),
        .o_full       (fifo_sum_full),
        .i_rd_en      (i_rd_en_sum),
        .o_rd_data_r  (o_sum_data),
        .o_empty      (o_fifo_sum_empty)
    );

endmodule
