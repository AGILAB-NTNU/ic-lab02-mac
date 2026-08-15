// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/13 10:44:33
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: mac
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立資料位元寬度為DATA_WIDTH參數 累加器與輸出位元寬度為ACC_WIDTH參數的mac
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

module mac #(
    parameter int DATA_WIDTH = 32, // 資料位元寬度 (32-bit)
    parameter int ACC_WIDTH  = 68  // 累加器與結果輸出位元寬度 (68-bit)
)(
    input wire i_clk,   // 時脈
    input wire i_rst_n, // 重置 (同步低電位有效)

    input wire i_acc_rst, // 累加器重置/開端訊號 (新一輪計算的第 1 筆)
    input wire i_calc_en, // 計算致能訊號

    input wire [DATA_WIDTH-1:0] i_a_data, // 輸入資料 A
    input wire [DATA_WIDTH-1:0] i_b_data, // 輸入資料 B

    // 當前累加狀態
    output wire [ACC_WIDTH-1:0] o_mac_data, // 當前累加器暫存器的即時數值

    // 10 筆累加完成結果介面
    output reg                  o_result_vld,  // 10 筆計算完成結果有效旗標
    output reg [ACC_WIDTH-1:0]  o_result_data, // 最終 10 筆乘累加總和結果

    // 外部接收端應答介面
    input wire i_result_rdy // 外部已讀取/接收結果應答訊號 (Ready)
);

    // 將輸入資料轉換為有符號數
    wire signed [DATA_WIDTH-1:0] a_signed;
    wire signed [DATA_WIDTH-1:0] b_signed;
    assign a_signed = $signed(i_a_data);
    assign b_signed = $signed(i_b_data);

    // 32-bit signed * 32-bit signed = 64-bit signed 乘積結果
    wire signed [DATA_WIDTH*2-1:0] mult_result;
    assign mult_result = a_signed * b_signed;

    // 將 64-bit 的乘積結果符號擴展至 68-bit
    wire signed [ACC_WIDTH-1:0] mult_extended;
    assign mult_extended = $signed(mult_result);

    // 內部狀態暫存器
    reg signed [ACC_WIDTH-1:0] mac_data_r; // 68-bit 累加暫存器
    reg [3:0]                  mac_count_r; // 0~9 的累加次數計數器

    // 連續 assign 輸出當前累加值
    assign o_mac_data = mac_data_r;

    // 乘累加計算與 Valid-Ready Handshake
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            // 系統重置
            mac_data_r    <= '0;
            mac_count_r   <= 4'd0;
            o_result_vld  <= 1'b0;
            o_result_data <= '0;
        end else begin

            // Handshake 清除邏輯：若 Valid 為高且接收端 Ready 拉高，則下一個週期清除 Valid
            if (o_result_vld && i_result_rdy) begin
                o_result_vld <= 1'b0;
            end

            // 計算致能時，執行 MAC 運算
            if (i_calc_en) begin

                // 情況一：開啟新一輪累加 (第 1 筆資料)
                if (i_acc_rst) begin
                    mac_data_r  <= mult_extended;
                    mac_count_r <= 4'd1;
                end

                // 情況二：進行中間累加 (第 2 ~ 9 筆資料)
                else if (mac_count_r < 4'd9) begin
                    mac_data_r  <= mac_data_r + mult_extended;
                    mac_count_r <= mac_count_r + 4'd1;
                end

                // 情況三：第 10 筆資料 (最後一筆累加完成)
                else begin
                    mac_data_r    <= mac_data_r + mult_extended;
                    o_result_data <= mac_data_r + mult_extended;
                    o_result_vld  <= 1'b1;
                    mac_count_r   <= 4'd0;
                end

            end

        end
    end

endmodule
