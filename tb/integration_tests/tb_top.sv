// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/13 16:06:33
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: tb_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立mac模組的頂層整合模組測試平台，負責對top模組進行功能驗證，並提供完整的測試流程與訊號監控。
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

module tb_top;

    // 1. 參數與時序設定
    parameter int DATA_WIDTH     = 32;          // 輸入資料位元寬度 (32-bit)
    parameter int ACC_WIDTH      = 68;          // 累加器與輸出結果位元寬度 (68-bit)

    parameter int IN_FIFO_DEP    = 16;          // 輸入端 FIFO 深度
    parameter int OUT_FIFO_DEP   = 8;           // 輸出端 FIFO 深度

    parameter int CLK_PERIOD     = 8;           // 時脈週期設定為 8ns (對應 125MHz 頻率)

    parameter int TOTAL_PATTERNS = 1000;        // 總測試資料筆數
    parameter int TOTAL_ROUNDS   = TOTAL_PATTERNS / 10; // 總計算輪數

    parameter int SIM_TIMEOUT_NS = 200_000;     // 模擬防呆超時上限 (200µs)

    // 2. 測試平台內部訊號宣告 (Testbench Signals)
    // --- 時脈與重置訊號 ---
    reg clk_r;
    reg rst_n_r;

    // DUT 輸入端：Input FIFO A 驅動訊號
    reg                  a_wren_r;
    reg [DATA_WIDTH-1:0] a_data_r;
    wire                 a_full_w;

    // DUT 輸入端：Input FIFO B 驅動訊號
    reg                  b_wren_r;
    reg [DATA_WIDTH-1:0] b_data_r;
    wire                 b_full_w;

    // DUT 輸出端：Output FIFO 監控與讀取訊號
    reg                  out_rden_r;
    wire [ACC_WIDTH-1:0] out_data_w;
    wire                 out_empty_w;
    wire                 out_full_w;

    // 測試資料與 Golden 數據暫存陣列
    reg [DATA_WIDTH-1:0] mem_a_r [TOTAL_PATTERNS]; // A 資料測試集
    reg [DATA_WIDTH-1:0] mem_b_r [TOTAL_PATTERNS]; // B 資料測試集
    reg [ACC_WIDTH-1:0]  golden_r [TOTAL_ROUNDS];   // 標準答案 (Golden Output)

    // 測試流程與統計計數器
    integer pattern_idx_r; // 當前寫入 pattern 索引
    integer round_idx_r;   // 當前驗證輪數索引
    integer err_cnt_r;     // 錯誤比對總數計數器
    integer pass_cnt_r;    // 正確比對總數計數器

    // 3. 待測物 (DUT: Device Under Test) 例化
    top #(
        .DATA_WIDTH   (DATA_WIDTH),
        .ACC_WIDTH    (ACC_WIDTH),
        .IN_FIFO_DEP  (IN_FIFO_DEP),
        .OUT_FIFO_DEP (OUT_FIFO_DEP)
    ) u_dut (
        .i_clk       (clk_r),
        .i_rst_n     (rst_n_r),

        // Input FIFO A
        .i_a_wren    (a_wren_r),
        .i_a_data    (a_data_r),
        .o_a_full    (a_full_w),

        // Input FIFO B
        .i_b_wren    (b_wren_r),
        .i_b_data    (b_data_r),
        .o_b_full    (b_full_w),

        // Output FIFO
        .i_out_rden  (out_rden_r),
        .o_out_data  (out_data_w),
        .o_out_empty (out_empty_w),
        .o_out_full  (out_full_w)
    );

    // 4. 時脈產生器 (Clock Generator)
    always #(CLK_PERIOD / 2)
        clk_r = ~clk_r; // 每 4ns 反轉一次，產生 8ns 週期的時脈

    // 5. 看門狗超時機制 (Timeout Watchdog: 防止死鎖導致無限模擬)
    initial begin
        #(SIM_TIMEOUT_NS);

        $display("");
        $display("==================================================");
        $display(" ERROR: SIMULATION TIMEOUT ");
        $display(" TIME = %0t", $time);
        $display("==================================================");

        $finish; // 強制終止模擬
    end

    // 6. 主驗證控制流程
    initial begin
        // Step 1: 初始化所有暫存器訊號
        clk_r      = 1'b0;
        rst_n_r    = 1'b0;

        a_wren_r   = 1'b0;
        a_data_r   = '0;

        b_wren_r   = 1'b0;
        b_data_r   = '0;

        out_rden_r = 1'b0;

        err_cnt_r  = 0;
        pass_cnt_r = 0;

        // Step 2: 載入外部 Pattern 與 Golden 十六進制檔
        $readmemh("input_a.hex", mem_a_r);
        $readmemh("input_b.hex", mem_b_r);
        $readmemh("golden.hex",  golden_r);

        $display("");
        $display("==================================================");
        $display("       Start Verification");
        $display("==================================================");

        // Step 3: 系統重置序列 (Reset Logic)
        repeat (5)
            @(posedge clk_r);

        rst_n_r = 1'b1; // 釋放低電位重置

        $display(
            "[TB] Reset released at time %0t",
            $time
        );

        repeat (2)
            @(posedge clk_r);

        // Step 4: 平行啟動寫入與讀取比對任務 (Fork-Join Parallel Execution)
        fork
            // Task 1：資料輸入寫入任務 (將 1000 筆 Pattern 填入 Input FIFO A/B)
            begin
                pattern_idx_r = 0;

                while (pattern_idx_r < TOTAL_PATTERNS) begin
                    // 於時脈下降沿更新輸入資料，避免正緣觸發時的競爭條件 (Race Condition)
                    @(negedge clk_r);

                    // 檢查 A/B FIFO 是否皆未處於 Full 狀態
                    if (!a_full_w && !b_full_w) begin
                        a_wren_r = 1'b1;
                        a_data_r = mem_a_r[pattern_idx_r];

                        b_wren_r = 1'b1;
                        b_data_r = mem_b_r[pattern_idx_r];

                        pattern_idx_r = pattern_idx_r + 1;
                    end else begin
                        // FIFO 滿時拉低 Write Enable，暫停寫入
                        a_wren_r = 1'b0;
                        b_wren_r = 1'b0;
                    end
                end

                // 全部資料寫入完成後，拉低寫入致能訊號
                @(negedge clk_r);

                a_wren_r = 1'b0;
                b_wren_r = 1'b0;

                $display(
                    "[TB] Finished writing %0d input patterns at time %0t",
                    TOTAL_PATTERNS,
                    $time
                );
            end

            // Task 2：結果讀取與自動比對驗證任務 (從 Output FIFO 取出結果並對照 Golden)
            begin
                for (
                    round_idx_r = 0;
                    round_idx_r < TOTAL_ROUNDS;
                    round_idx_r = round_idx_r + 1
                ) begin
                    // 輪詢等待 Output FIFO 處於非 Empty 狀態 (代表 MAC 算出了一筆結果)
                    while (out_empty_w) begin
                        @(posedge clk_r);
                    end

                    // 下降沿送出 Read Enable 觸發讀取
                    @(negedge clk_r);
                    out_rden_r = 1'b1;

                    // 跨越一個 Clock 正緣完成 FIFO 數據取用
                    @(posedge clk_r);

                    // 下降沿關閉 Read Enable
                    @(negedge clk_r);
                    out_rden_r = 1'b0;

                    // 預留小延遲等待組合邏輯與輸出資料穩定
                    #1;

                    // 自動比對硬體輸出 (HW Output) 與黃金答案 (Golden Data)
                    if (out_data_w === golden_r[round_idx_r]) begin
                        pass_cnt_r = pass_cnt_r + 1;

                        $display(
                            "[PASS] Round %3d : HW_OUT = 0x%017h   GOLDEN_OUT = 0x%017h",
                            round_idx_r + 1,
                            out_data_w,
                            golden_r[round_idx_r]
                        );
                    end else begin
                        err_cnt_r = err_cnt_r + 1;

                        $display(
                            "[FAIL] Round %3d : HW_OUT = 0x%017h   GOLDEN_OUT = 0x%017h",
                            round_idx_r + 1,
                            out_data_w,
                            golden_r[round_idx_r]
                        );
                    end
                end

                // Step 5: 所有輪數驗證完畢，印出統計結果
                repeat (5)
                    @(posedge clk_r);

                $display("");
                $display("==================================================");

                if (err_cnt_r == 0) begin
                    $display(
                        " ALL %0d PATTERNS (%0d ROUNDS) PASSED! ",
                        TOTAL_PATTERNS,
                        TOTAL_ROUNDS
                    );
                end else begin
                    $display(
                        " TEST FAILED! Total Errors: %0d ",
                        err_cnt_r
                    );
                end

                $display(
                    " PASS COUNT = %0d / %0d ",
                    pass_cnt_r,
                    TOTAL_ROUNDS
                );

                $display("==================================================");

                // 正常結束模擬
                $finish;
            end
        join // 等待 Task 1 與 Task 2 皆完成後結束
    end

endmodule
