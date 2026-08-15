// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/14 14:35:30
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: tb_sync_fifo
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立sync_fifo模組的測試平台，負責對sync_fifo模組進行功能驗證，並提供完整的測試流程與訊號監控。
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

module tb_sync_fifo;

    // 1. 參數設定
    parameter int DATA_WIDTH = 32; // 資料位元寬度
    parameter int DEPTH      = 8;  // FIFO 深度

    // 2. Testbench 內部訊號宣告
    reg clk;                    // 時脈訊號
    reg rst_n;                  // 低電位有效重置訊號

    reg wr_en;                  // 寫入致能
    reg [DATA_WIDTH-1:0] din;   // 寫入資料輸入
    wire full;                  // FIFO 已滿旗標

    reg rd_en;                  // 讀出致能
    wire [DATA_WIDTH-1:0] dout; // 讀出資料輸出
    wire data_vld;              // 讀出資料有效旗標
    wire empty;                 // FIFO 為空旗標

    // 3. 實體化待測模組 (DUT)
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) u_fifo (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_wren(wr_en),
        .i_data(din),
        .o_full(full),
        .i_rden(rd_en),
        .o_data(dout),
        .o_data_vld(data_vld),
        .o_empty(empty)
    );

    // 每 4ns 翻轉一次，週期 8ns (對應 125MHz)
    always #4 clk = ~clk;

    // 檔案處理與驗證統計變數
    integer in_file;            // 輸入測試向量檔案指標
    integer gold_file;          // Golden Output 正確答案檔案指標

    integer status_in;          // 記錄 input 檔案讀取狀態
    integer status_gold;        // 記錄 golden 檔案讀取狀態

    reg [DATA_WIDTH-1:0] expected_dout; // 儲存從 Golden 檔讀出的預期資料

    integer error_count = 0;    // 錯誤筆數計數器
    integer match_count = 0;    // 成功比對筆數計數器

    // 4. 驅動程序 (Stimulus Block)
    initial begin
        // 初始化控制訊號，避免產生不定態 (X)
        clk   = 1'b0;
        rst_n = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        din   = '0;

        // 開啟 Python 產生的測試向量檔
        in_file   = $fopen("input_vectors.hex", "r");
        gold_file = $fopen("golden_outputs.hex", "r");

        // 檢查輸入測試檔是否存在
        if (in_file == 0) begin
            $display("[ERROR] Cannot open input_vectors.hex");
            $finish;
        end

        // 檢查 Golden 答案檔是否存在
        if (gold_file == 0) begin
            $display("[ERROR] Cannot open golden_outputs.hex");
            $finish;
        end

        // 系統重置階段 (Reset Phase)
        #16;         // 保持 Reset 狀態 16ns (兩個時脈週期)
        rst_n = 1'b1; // 釋放 Reset

        // 等待一個完整 clock 正緣，確保硬體狀態已穩定
        @(posedge clk);

        $display("===========================================");
        $display("   Starting Python - Verilog Verification");
        $display("===========================================");

        // 逐筆輸入
        while (!$feof(in_file)) begin
            @(negedge clk); // 在下降沿觸發讀檔與給值

            // 從 input_vectors.hex 讀取一行的 wr_en, rd_en, din (Hex 格式)
            status_in = $fscanf(
                in_file,
                "%b %b %h\n",
                wr_en,
                rd_en,
                din
            );

            // 若讀檔不成功或已無資料，將致能訊號歸零
            if (status_in != 3) begin
                wr_en = 1'b0;
                rd_en = 1'b0;
                din   = '0;
            end
        end

        // 測試向量讀取完畢，停止輸入
        @(negedge clk);

        wr_en = 1'b0;
        rd_en = 1'b0;
        din   = '0;

        $fclose(in_file); // 關閉輸入檔

        // 清空與等待階段 (Flush & Wait)
        // 額外等待 5 個時脈週期，確保最後幾筆讀取資料正確輸出並被 Monitor 採樣
        repeat (5)
            @(posedge clk);

        // 印出最終驗證統計結果
        $display("===========================================");
        $display(" Verification Summary:");
        $display(" Total Passed : %0d", match_count);
        $display(" Total Failed : %0d", error_count);
        $display("===========================================");

        if (error_count == 0 && match_count > 0)
            $display(">>> TEST PASSED: All vectors matched perfectly! <<<");
        else
            $display(">>> TEST FAILED: Discrepancy found! <<<");

        $fclose(gold_file); // 關閉 Golden 檔

        $finish; // 結束模擬
    end

    // 5. 自動監視與比對器
    always @(posedge clk) begin
        #1; // 延遲 1ns 等待輸出穩定

        // 當系統不在 Reset 狀態，且 DUT 輸出資料有效時 (data_vld == 1)
        if (rst_n && data_vld) begin
            // 確保 Golden 檔還有預期資料可供比對
            if (!$feof(gold_file)) begin
                // 讀取一行預期的答案 (16 進位)
                status_gold = $fscanf(
                    gold_file,
                    "%h\n",
                    expected_dout
                );

                // 讀檔失敗處理
                if (status_gold != 1) begin
                    $display("[FAIL] Cannot read golden output!");
                    error_count = error_count + 1;
                end
                // 比對成功：RTL dout 與 Golden expected_dout 完全相同
                else if (dout === expected_dout) begin
                    $display(
                        "[PASS] Read: 0x%08X | Expected: 0x%08X",
                        dout,
                        expected_dout
                    );
                    match_count = match_count + 1;
                end
                // 比對失敗：資料不一致
                else begin
                    $display(
                        "[FAIL] Read: 0x%08X | Expected: 0x%08X <--- ERROR!",
                        dout,
                        expected_dout
                    );
                    error_count = error_count + 1;
                end
            end
            // 若 Golden 檔已無資料，RTL 卻還拉高 data_vld，代表發生不預期的多餘讀出
            else begin
                $display("[FAIL] Unexpected valid data output!");
                error_count = error_count + 1;
            end
        end
    end

endmodule
