// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/14 15:43:04
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: tb_controller
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立controller模組的測試平台，負責對controller模組進行功能驗證，並提供完整的測試流程與訊號監控。
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

`timescale 1ns/1ps

module tb_controller;

    // 1. 時脈與重置訊號 (Clock / Reset)
    reg i_clk;                  // 系統時脈
    reg i_rst_n;                // 低電位有效重置訊號

    // 2. 待測模組輸入訊號 (DUT Inputs)
    reg i_a_empty;              // FIFO A 為空旗標
    reg i_b_empty;              // FIFO B 為空旗標

    reg i_a_data_vld;           // FIFO A 資料有效訊號 (對應 RTL o_a_data_vld)
    reg i_b_data_vld;           // FIFO B 資料有效訊號 (對應 RTL o_b_data_vld)

    reg i_out_full;             // 輸出 FIFO 已滿旗標

    reg i_mac_result_vld;       // MAC 計算結果有效訊號

    // 3. 待測模組輸出訊號 (DUT Outputs)
    wire o_in_fifo_rden;        // Input FIFO A/B 讀出致能
    wire o_calc_en;             // MAC 計算致能
    wire o_acc_rst;             // MAC 累加器歸零訊號

    wire o_out_fifo_wren;       // 輸出 FIFO 寫入致能

    wire o_mac_result_rdy;      // MAC 結果接收準備完成訊號

    // 4. 實體化待測模組 (Instantiate DUT)
    controller u_controller (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),

        .i_a_empty          (i_a_empty),
        .i_b_empty          (i_b_empty),

        .i_a_data_vld       (i_a_data_vld),
        .i_b_data_vld       (i_b_data_vld),

        .i_out_full         (i_out_full),

        .i_mac_result_vld   (i_mac_result_vld),

        .o_in_fifo_rden     (o_in_fifo_rden),
        .o_calc_en          (o_calc_en),
        .o_acc_rst          (o_acc_rst),

        .o_out_fifo_wren    (o_out_fifo_wren),

        .o_mac_result_rdy   (o_mac_result_rdy)
    );

    // 5. 時脈產生器
    always #4 i_clk = ~i_clk;

    // 6. 檔案處理指標與狀態變數
    integer in_file;            // 輸入測試向量檔案指標
    integer gold_file;          // Golden Output 正確答案檔案指標

    integer status_in;          // 讀取輸入測試檔之狀態指標
    integer status_gold;        // 讀取 Golden 檔之狀態指標

    // 7. 輸入測試向量暫存暫存器
    reg next_a_empty;
    reg next_b_empty;

    reg next_a_data_vld;
    reg next_b_data_vld;

    reg next_out_full;
    reg next_mac_result_vld;

    // 8. 正確答案預期值暫存器
    reg expected_in_fifo_rden;
    reg expected_calc_en;
    reg expected_acc_rst;

    reg expected_out_fifo_wren;
    reg expected_mac_result_rdy;

    // 9. 驗證統計計數器
    integer total_count;        // 總測試週期數
    integer match_count;        // 成功比對數
    integer error_count;        // 失敗/錯誤筆數

    // 10. 主測試程序
    initial begin
        // 控制訊號初始化 (避免未定態 X)
        i_clk              = 1'b0;
        i_rst_n            = 1'b0;

        i_a_empty          = 1'b1;
        i_b_empty          = 1'b1;

        i_a_data_vld       = 1'b0;
        i_b_data_vld       = 1'b0;

        i_out_full         = 1'b0;

        i_mac_result_vld   = 1'b0;

        total_count        = 0;
        match_count        = 0;
        error_count        = 0;

        // 開啟輸入測試向量檔
        in_file = $fopen("controller_input_vectors.hex", "r");

        if (in_file == 0) begin
            $display("");
            $display("==============================================");
            $display("[ERROR] Cannot open input vector file!");
            $display("File: controller_input_vectors.hex");
            $display("==============================================");
            $display("");
            $finish;
        end

        // 開啟 Golden Output 答案檔
        gold_file = $fopen("controller_golden_outputs.hex", "r");

        if (gold_file == 0) begin
            $display("");
            $display("==============================================");
            $display("[ERROR] Cannot open golden output file!");
            $display("File: controller_golden_outputs.hex");
            $display("==============================================");
            $display("");

            $fclose(in_file);
            $finish;
        end

        // 系統硬體重置階段 (Reset Phase)
        i_rst_n = 1'b0;

        // 保持 Reset 狀態 3 個時脈週期
        repeat (3)
            @(posedge i_clk);

        // 在時脈下降沿釋放 Reset，確保下一個正緣來臨時重置狀態已穩定
        @(negedge i_clk);
        i_rst_n = 1'b1;

        // 印出開始驗證訊息
        $display("");
        $display("================================================");
        $display("        CONTROLLER VERIFICATION START");
        $display("================================================");
        $display("");

        // 預先讀取第一筆測試向量
        status_in = $fscanf(
            in_file,
            "%b %b %b %b %b %b\n",
            next_a_empty,
            next_b_empty,
            next_a_data_vld,
            next_b_data_vld,
            next_out_full,
            next_mac_result_vld
        );

        // 主要驗證迴圈
        while (status_in == 6) begin
            // 驅動輸入測試向量至 DUT
            i_a_empty        = next_a_empty;
            i_b_empty        = next_b_empty;

            i_a_data_vld     = next_a_data_vld;
            i_b_data_vld     = next_b_data_vld;

            i_out_full       = next_out_full;

            i_mac_result_vld = next_mac_result_vld;

            // 等待組合邏輯傳播穩定 (Combinational Settling)
            #1;

            // 從答案檔讀取 Golden Output
            status_gold = $fscanf(
                gold_file,
                "%b %b %b %b %b\n",
                expected_in_fifo_rden,
                expected_calc_en,
                expected_acc_rst,
                expected_out_fifo_wren,
                expected_mac_result_rdy
            );

            // 檢查 Golden 檔案讀取狀態與格式
            if (status_gold != 5) begin
                $display("");
                $display("[FAIL] Golden file format / EOF error!");
                $display("       Cycle = %0d", total_count + 1);
                $display("");

                error_count = error_count + 1;
            end else begin
                total_count = total_count + 1;

                // 比對 DUT 輸出 vs. Golden 正確答案
                if (
                    (o_in_fifo_rden === expected_in_fifo_rden) &&
                    (o_calc_en === expected_calc_en) &&
                    (o_acc_rst === expected_acc_rst) &&
                    (o_out_fifo_wren === expected_out_fifo_wren) &&
                    (o_mac_result_rdy === expected_mac_result_rdy)
                ) begin
                    // 比對成功 (PASS)
                    match_count = match_count + 1;

                    $display(
                        "[PASS] Cycle=%0d | ",
                        "fifo_rden=%b calc=%b acc_rst=%b wren=%b ready=%b",
                        total_count,
                        o_in_fifo_rden,
                        o_calc_en,
                        o_acc_rst,
                        o_out_fifo_wren,
                        o_mac_result_rdy
                    );
                end else begin
                    // 比對失敗 (FAIL) - 印出詳細錯資訊以利 Debug
                    error_count = error_count + 1;

                    $display("");
                    $display("[FAIL] Cycle=%0d", total_count);

                    // 錯訊詳細內容：當前輸入條件
                    $display(
                        "INPUT : ",
                        "a_empty=%b, b_empty=%b, a_vld=%b, b_vld=%b, out_full=%b, mac_vld=%b",
                        i_a_empty,
                        i_b_empty,
                        i_a_data_vld,
                        i_b_data_vld,
                        i_out_full,
                        i_mac_result_vld
                    );

                    // 錯訊詳細內容：DUT 實際輸出
                    $display(
                        "DUT   : ",
                        "fifo_rden=%b, calc=%b, acc_rst=%b, wren=%b, ready=%b",
                        o_in_fifo_rden,
                        o_calc_en,
                        o_acc_rst,
                        o_out_fifo_wren,
                        o_mac_result_rdy
                    );

                    // 錯訊詳細內容：Golden 預期輸出
                    $display(
                        "GOLD  : ",
                        "fifo_rden=%b, calc=%b, acc_rst=%b, wren=%b, ready=%b",
                        expected_in_fifo_rden,
                        expected_calc_en,
                        expected_acc_rst,
                        expected_out_fifo_wren,
                        expected_mac_result_rdy
                    );

                    $display("");
                end
            end

            // 等待下一個時脈下降沿 (negedge)
            @(negedge i_clk);

            // 讀取下一個測試向量
            status_in = $fscanf(
                in_file,
                "%b %b %b %b %b %b\n",
                next_a_empty,
                next_b_empty,
                next_a_data_vld,
                next_b_data_vld,
                next_out_full,
                next_mac_result_vld
            );
        end

        // 測試向量讀取完成，重置所有輸入訊號
        i_a_empty        = 1'b1;
        i_b_empty        = 1'b1;

        i_a_data_vld     = 1'b0;
        i_b_data_vld     = 1'b0;

        i_out_full       = 1'b0;

        i_mac_result_vld = 1'b0;

        // 關閉輸入檔
        $fclose(in_file);

        // 檢查 Golden 答案檔是否還有未讀完的殘留資料
        if (!$feof(gold_file)) begin
            $display("");
            $display("[WARNING] Golden file still contains data!");
            $display("");
        end

        // 關閉 Golden 檔
        $fclose(gold_file);

        // 總結報告 (Final Summary Report)
        $display("");
        $display("================================================");
        $display("              Verification Summary");
        $display("================================================");

        $display("Total Cycles : %0d", total_count);
        $display("Total Passed : %0d", match_count);
        $display("Total Failed : %0d", error_count);

        $display("================================================");

        // 最終驗證結果顯示
        if ((error_count == 0) && (match_count > 0)) begin
            $display("");
            $display(">>> TEST PASSED <<<");
            $display(">>> All vectors matched perfectly! <<<");
            $display("");
        end else begin
            $display("");
            $display(">>> TEST FAILED <<<");
            $display(">>> Discrepancy found! <<<");
            $display("");
        end

        // 結束模擬
        $finish;
    end

endmodule
