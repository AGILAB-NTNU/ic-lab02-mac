// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/14 14:59:21
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: tb_mac
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立mac模組的測試平台，負責對mac模組進行功能驗證，並提供完整的測試流程與訊號監控。
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

module tb_mac;

    // 1. 參數設定
    parameter int DATA_WIDTH = 32; // 輸入資料位元寬度
    parameter int ACC_WIDTH  = 68; // 累加器資料位元寬度

    // 2. Testbench 內部訊號宣告
    reg i_clk;                      // 系統時脈
    reg i_rst_n;                    // 低電位有效重置訊號

    reg i_acc_rst;                  // 累加器歸零/重置控制訊號
    reg i_calc_en;                  // 計算致能訊號 (Enable)

    reg [DATA_WIDTH-1:0] i_a_data;  // 被乘數 A 輸入
    reg [DATA_WIDTH-1:0] i_b_data;  // 乘數 B 輸入

    wire [ACC_WIDTH-1:0] o_mac_data; // 即時 MAC 累加結果輸出

    wire o_result_vld;              // 最終結果有效旗標
    wire [ACC_WIDTH-1:0] o_result_data; // 最終運算結果輸出

    reg i_result_rdy;             // 下游接收端準備好旗標

    // 3. 實體化待測模組 (DUT: Device Under Test)
    mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_mac (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),

        .i_acc_rst      (i_acc_rst),
        .i_calc_en      (i_calc_en),

        .i_a_data       (i_a_data),
        .i_b_data       (i_b_data),

        .o_mac_data     (o_mac_data),

        .o_result_vld   (o_result_vld),
        .o_result_data  (o_result_data),

        .i_result_rdy (i_result_rdy)
    );

    // 時脈產生器 (Clock Generator)
    // 每 4ns 翻轉一次，週期 8ns (對應 125MHz)
    always #4 i_clk = ~i_clk;

    // 檔案處理指標與讀檔狀態變數
    integer in_file;     // 輸入測試向量檔案指標
    integer gold_file;   // Golden Output 正確答案檔案指標

    integer status_in;   // 記錄 input 檔案讀取狀態
    integer status_gold; // 記錄 golden 檔案讀取狀態

    // 答案儲存暫存器
    reg [ACC_WIDTH-1:0] expected_result; // 儲存從 Golden 檔讀出的預期運算結果

    // 驗證統計計數器
    integer error_count; // 錯誤筆數計數器
    integer match_count; // 成功比對筆數計數器

    // 輸入測試向量暫存變數 (暫存從檔案讀出的當筆內容)
    reg [DATA_WIDTH-1:0] next_a;
    reg [DATA_WIDTH-1:0] next_b;

    reg next_acc_rst;
    reg next_calc_en;
    reg next_ready;

    // 4. 主驅動程序
    initial begin
        // 控制訊號初始化
        i_clk          = 1'b0;
        i_rst_n        = 1'b0;

        i_acc_rst      = 1'b0;
        i_calc_en      = 1'b0;

        i_a_data       = '0;
        i_b_data       = '0;

        i_result_rdy = 1'b0;

        error_count    = 0;
        match_count    = 0;

        // 開啟測試檔與答案檔
        in_file   = $fopen("mac_input_vectors.hex", "r");
        gold_file = $fopen("mac_golden_outputs.hex", "r");

        // 檢查輸入測試檔是否存在
        if (in_file == 0) begin
            $display("[ERROR] Cannot open mac_input_vectors.hex");
            $finish;
        end

        // 檢查 Golden 答案檔是否存在
        if (gold_file == 0) begin
            $display("[ERROR] Cannot open mac_golden_outputs.hex");
            $finish;
        end

        // 系統硬體重置階段
        i_rst_n = 1'b0;

        // 保持 Reset 狀態 3 個時脈週期
        repeat (3)
            @(posedge i_clk);

        // 在時脈下降沿釋放 Reset，避免與正緣競爭
        @(negedge i_clk);
        i_rst_n = 1'b1;

        $display("");
        $display("==============================================");
        $display("       MAC Python - Verilog Verification");
        $display("==============================================");
        $display("");

        // 逐筆讀取輸入測試向量
        while (!$feof(in_file)) begin
            @(negedge i_clk); // 在時脈下降沿觸發讀檔與更新輸入

            // 從檔內讀取格式: acc_rst(1b) calc_en(1b) a_data(hex) b_data(hex) ready(1b)
            status_in = $fscanf(
                in_file,
                "%b %b %h %h %b\n",
                next_acc_rst,
                next_calc_en,
                next_a,
                next_b,
                next_ready
            );

            // 成功讀取 5 個欄位時，將暫存值驅動至 DUT 輸入端
            if (status_in == 5) begin
                i_acc_rst      = next_acc_rst;
                i_calc_en      = next_calc_en;

                i_a_data       = next_a;
                i_b_data       = next_b;

                i_result_rdy = next_ready;
            end
            // 若讀檔不成功或已達檔案末端，將驅動訊號歸零
            else begin
                i_acc_rst      = 1'b0;
                i_calc_en      = 1'b0;

                i_a_data       = '0;
                i_b_data       = '0;

                i_result_rdy = 1'b0;
            end
        end

        // 測試向量讀取完畢，拉低所有控制訊號
        @(negedge i_clk);

        i_acc_rst      = 1'b0;
        i_calc_en      = 1'b0;

        i_a_data       = '0;
        i_b_data       = '0;

        i_result_rdy = 1'b0;

        $fclose(in_file); // 關閉輸入檔

        // 讀取結束後的緩衝等待階段 (Wait for final result)
        // 額外等待 5 個週期，確保管線 (Pipeline) 內的運算全數輸出並被檢查
        repeat (5)
            @(posedge i_clk);

        // 印出最終驗證統計結果 (Summary Report)
        $display("");
        $display("==============================================");
        $display("              Verification Summary");
        $display("==============================================");

        $display("Total Passed : %0d", match_count);
        $display("Total Failed : %0d", error_count);

        $display("==============================================");

        if ((error_count == 0) && (match_count > 0)) begin
            $display("");
            $display(">>> TEST PASSED <<<");
            $display(">>> All MAC results matched! <<<");
            $display("");
        end else begin
            $display("");
            $display(">>> TEST FAILED <<<");
            $display(">>> MAC result mismatch detected! <<<");
            $display("");
        end

        $fclose(gold_file); // 關閉 Golden 檔

        $finish; // 結束模擬
    end

    // 5. 結果監視與比對器 (Result Monitor & Scoreboard)
    always @(posedge i_clk) begin
        #1; // 延遲 1ns 避開 Timing Race Condition

        // 當系統不在 Reset 狀態，且 MAC 輸出 Valid 訊號時觸發比對
        if (i_rst_n && o_result_vld) begin
            // 確保 Golden 檔案內還有預期答案可讀取
            if (!$feof(gold_file)) begin
                status_gold = $fscanf(
                    gold_file,
                    "%h\n",
                    expected_result
                );

                // 讀檔失敗處理
                if (status_gold != 1) begin
                    $display("[FAIL] Cannot read golden result!");
                    error_count = error_count + 1;
                end
                // 比對成功：DUT 輸出 data 與 Golden 預期值完全吻合
                else if (o_result_data === expected_result) begin
                    $display(
                        "[PASS] Result = 0x%017X | Expected = 0x%017X",
                        o_result_data,
                        expected_result
                    );
                    match_count = match_count + 1;
                end
                // 比對失敗：計算結果不一致
                else begin
                    $display(
                        "[FAIL] Result = 0x%017X | Expected = 0x%017X",
                        o_result_data,
                        expected_result
                    );
                    error_count = error_count + 1;
                end
            end
            // 若 Golden 檔已無資料，DUT 卻還拉高 vld，代表發生了不預期的多餘輸出
            else begin
                $display("[FAIL] Unexpected result_vld! Golden file already reached EOF.");
                error_count = error_count + 1;
            end
        end
    end

endmodule
