// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/13 14:41:45
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: controller
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立mac模組的控制器，負責管理mac模組的運作流程，包括累加器重置、計算致能、結果有效旗標以及外部應答訊號的處理。
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

module controller (
    input wire i_clk,   // 時脈
    input wire i_rst_n, // 重置 (Reset)

    // Input FIFO 狀態介面
    input wire i_a_empty, // FIFO A 空旗標
    input wire i_b_empty, // FIFO B 空旗標

    // Input FIFO 資料有效介面
    input wire i_a_data_vld, // FIFO A 讀出資料有效旗標
    input wire i_b_data_vld, // FIFO B 讀出資料有效旗標

    // Output FIFO 狀態介面
    input wire i_out_full, // Output FIFO 滿旗標

    // MAC 計算結果握手介面
    input wire i_mac_result_vld, // MAC 10 筆計算完成輸出有效旗標

    // 控制輸出介面
    output wire o_in_fifo_rden, // 觸發 Input FIFO A/B 同步讀取的致能訊號

    output wire o_calc_en, // 傳給 MAC 的計算致能訊號
    output wire o_acc_rst, // 傳給 MAC 的累加器重置訊號 (標記新一輪 10 次計算開端)

    output wire o_out_fifo_wren, // 傳給 Output FIFO 的寫入致能訊號

    output wire o_mac_result_rdy // 傳給 MAC 的結果接收準備就緒訊號 (Handshake rdy)
);

    // 內部暫存器：計算筆數計數器 (0~9，共 10 筆)
    reg [3:0] calc_count_r;

    // 當 FIFO A 與 FIFO B 的資料同時有效時，才認定輸入資料有效
    wire input_data_vld;
    assign input_data_vld = i_a_data_vld && i_b_data_vld;

    // 只要 Output FIFO 未滿，就代表準備好接收 MAC 計算完成的結果
    assign o_mac_result_rdy = !i_out_full;

    // 當 MAC 結果有效且 Output FIFO 未滿時，寫入 Output FIFO (完成握手)
    assign o_out_fifo_wren = i_mac_result_vld && !i_out_full;

    // 當輸入資料有效且 MAC 未處於等待結果寫入鎖定狀態時，允許 MAC 進行計算
    assign o_calc_en = input_data_vld && !i_mac_result_vld;

    // 當進行計算且計數器為 0 時，拉高累加器重置訊號 (告知 MAC 重置為第一筆)
    assign o_acc_rst = o_calc_en && (calc_count_r == 4'd0);

    // Input FIFO 讀取致能條件
    // 條件：A/B FIFO 均不為空 + Output FIFO 未滿 + MAC 無待寫入結果 + 防止第 10 筆資料過度讀取 (Pipeline 流水線保護)
    assign o_in_fifo_rden = (!i_a_empty) &&
                            (!i_b_empty) &&
                            (!i_out_full) &&
                            (!i_mac_result_vld) &&
                            !(input_data_vld && (calc_count_r == 4'd9));

    // 更新 0~9 計算計數器 (嚴格遵守「同步重置」規範，移除 or negedge i_rst_n)
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            // 系統重置：計數器歸零
            calc_count_r <= '0;
        end else begin
            // 僅在計算致能拉高時推進計數器
            if (o_calc_en) begin
                if (calc_count_r == 4'd9) begin
                    // 已完成一組 (10 筆) 運算：計數器環形歸零，準備下一輪
                    calc_count_r <= 4'd0;
                end else begin
                    // 未滿 10 筆：計數器遞增
                    calc_count_r <= calc_count_r + 4'd1;
                end
            end
        end
    end

endmodule
