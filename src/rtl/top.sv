// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/13 15:24:29
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: top
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立mac模組的頂層整合模組，負責將mac模組、controller模組以及三個fifo模組整合在一起，並提供完整的資料流與控制訊號介面。
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

module top #(
    parameter int DATA_WIDTH   = 32, // 輸入資料位元寬度 (32-bit)
    parameter int ACC_WIDTH    = 68, // 累加器與 Output FIFO 位元寬度 (68-bit)
    parameter int IN_FIFO_DEP  = 16, // 輸入端 FIFO 深度
    parameter int OUT_FIFO_DEP = 8   // 輸出端 FIFO 深度
)(
    input wire i_clk,   // 時脈
    input wire i_rst_n, // 重置 (Reset)

    // 輸入端 A FIFO 介面
    input wire                  i_a_wren, // A 端寫入致能
    input wire [DATA_WIDTH-1:0] i_a_data, // A 端輸入資料
    output wire                 o_a_full, // A 端 FIFO 滿旗標

    // 輸入端 B FIFO 介面
    input wire                  i_b_wren, // B 端寫入致能
    input wire [DATA_WIDTH-1:0] i_b_data, // B 端輸入資料
    output wire                 o_b_full, // B 端 FIFO 滿旗標

    // 輸出端 FIFO 介面
    input wire                 i_out_rden, // 輸出端讀取致能
    output wire [ACC_WIDTH-1:0] o_out_data, // 輸出端資料 (68-bit 乘累加結果)
    output wire                 o_out_empty, // 輸出端 FIFO 空旗標
    output wire                 o_out_full  // 輸出端 FIFO 滿旗標
);

    // --- 內部連線訊號宣告 ---
    // Input FIFO A 輸出與狀態
    wire [DATA_WIDTH-1:0] a_dout;
    wire                  a_empty;
    wire                  a_data_vld;

    // Input FIFO B 輸出與狀態
    wire [DATA_WIDTH-1:0] b_dout;
    wire                  b_empty;
    wire                  b_data_vld;

    // 控制器對 Input FIFO 的讀取致能
    wire in_fifo_rden;

    // MAC 控制訊號
    wire calc_en;
    wire acc_rst;

    // Output FIFO 寫入控制訊號
    wire out_fifo_wren;

    // MAC 與 Controller 之間的握手 (Handshake) 訊號
    wire                  mac_result_rdy;
    wire [ACC_WIDTH-1:0]  mac_data;
    wire                  mac_result_vld;
    wire [ACC_WIDTH-1:0]  mac_result_data;

    // 1. 例化 Input FIFO A (儲存輸入資料 A)
    sync_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (IN_FIFO_DEP)
    ) u_input_fifo_a (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),

        .i_wren       (i_a_wren),
        .i_data       (i_a_data),
        .o_full       (o_a_full),

        .i_rden       (in_fifo_rden),
        .o_data       (a_dout),
        .o_data_vld (a_data_vld),
        .o_empty      (a_empty)
    );

    // 2. 例化 Input FIFO B (儲存輸入資料 B)
    sync_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (IN_FIFO_DEP)
    ) u_input_fifo_b (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),

        .i_wren       (i_b_wren),
        .i_data       (i_b_data),
        .o_full       (o_b_full),

        .i_rden       (in_fifo_rden),
        .o_data       (b_dout),
        .o_data_vld (b_data_vld),
        .o_empty      (b_empty)
    );

    // 3. 例化控制器 (Controller: 協調 FIFO 讀寫與 MAC 運算時序)
    controller u_controller (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),

        .i_a_empty        (a_empty),
        .i_b_empty        (b_empty),

        .i_a_data_vld     (a_data_vld),
        .i_b_data_vld     (b_data_vld),

        .i_out_full       (o_out_full),

        .i_mac_result_vld (mac_result_vld),

        .o_in_fifo_rden   (in_fifo_rden),

        .o_calc_en        (calc_en),
        .o_acc_rst        (acc_rst),

        .o_out_fifo_wren  (out_fifo_wren),

        .o_mac_result_rdy (mac_result_rdy)
    );

    // 4. 例化乘累加單元 (MAC: 執行 10 筆資料的乘加運算)
    mac #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) u_mac (
        .i_clk         (i_clk),
        .i_rst_n       (i_rst_n),

        .i_acc_rst     (acc_rst),
        .i_calc_en     (calc_en),

        .i_a_data      (a_dout),
        .i_b_data      (b_dout),

        .o_mac_data    (mac_data),

        .o_result_vld  (mac_result_vld),
        .o_result_data (mac_result_data),

        .i_result_rdy  (mac_result_rdy)
    );

    // 5. 例化 Output FIFO (儲存 MAC 計算完成的 68-bit 累加結果)
    sync_fifo #(
        .DATA_WIDTH (ACC_WIDTH),
        .DEPTH      (OUT_FIFO_DEP)
    ) u_output_fifo (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),

        .i_wren       (out_fifo_wren),
        .i_data       (mac_result_data),
        .o_full       (o_out_full),

        .i_rden       (i_out_rden),
        .o_data       (o_out_data),

        // 頂層模組不需使用 Output FIFO 的 data_valid 訊號，故懸空
        .o_data_vld (),

        .o_empty      (o_out_empty)
    );

endmodule
