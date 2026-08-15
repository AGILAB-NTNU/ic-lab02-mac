// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/14 14:06:32
// Design Type: Testbench (Simulation Only)
// Design Name: ic-lab02-mac
// Module Name: tb_mac_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立系統級測試 MAC 的 testbench
// Coding Rules:
//   Type       : Testbench (Simulation Only)
//   SV Syntax  : Testbench (Simulation Only)Full SystemVerilog syntax allowed for simulation
//   Ports      : i_* = inputs, o_* = outputs (e.g. iclk, i_rst_n, i_a, i_b, o_y)
//   Regs       : *_r = registers, *_next = combinational next-state signals
//   Reset      : active-low synchronous reset (i_rst_n), posedge iclk only
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

module tb_mac_top;

    // 參數: 必須與 generate_golden.py 執行時的 --m / --n 一致！
    localparam integer Mblocks   = 5;   // 對應 python 腳本的 --m (區塊數)
    localparam integer N         = 10;  // 對應 python 腳本的 --n (每區塊筆數，需與RTL的N一致)
    localparam integer Datawidth = 8;
    localparam integer Accwidth  = 32;
    localparam integer Fifodepth = 16;
    localparam integer Sumdepth  = 16;
    localparam integer Clkperiod = 8;

    // hex 檔案路徑：預設放在與 TB 同一層的 sim_data/ 目錄下，
    // 可依實際 Vivado 專案結構自行修改 (詳見檔案最下方說明)
    localparam string Ahexfile    = "input_A.hex";
    localparam string Bhexfile    = "input_B.hex";
    localparam string Goldenhexfile = "golden_sum.hex";

    reg clk;
    reg rst_n;
    reg i_en;

    reg wr_en_a;
    reg [Datawidth-1:0] a_wdata;
    wire fifo_a_full;

    reg wr_en_b;
    reg [Datawidth-1:0] b_wdata;
    wire fifo_b_full;

    reg rd_en_sum;
    wire [Accwidth-1:0] sum_data;
    wire fifo_sum_empty;

    wire dbg_rd_en, dbg_acc_en, dbg_acc_clr, dbg_sum_wr_en;

    // 由 hex 檔讀入的記憶體陣列
    reg [Datawidth-1:0] a_mem [Mblocks*N-1];  // 攤平後的 A 資料 (共 M*N 筆)
    reg [Datawidth-1:0] b_mem [Mblocks*N-1];  // 攤平後的 B 資料 (共 M*N 筆)
    reg [Accwidth-1:0] gold_mem [Mblocks-1];  // 每個 block 的 Golden Sum (共 M 筆)

    integer error_count;
    integer pass_count;
    integer blk, idx;

    // DUT
    mac_top #(
        .N           (N),
        .DATA_W      (Datawidth),
        .ACC_W       (Accwidth),
        .FIFO_DEPTH  (Fifodepth),
        .SUM_DEPTH   (Sumdepth)
    ) dut (
        .i_clk            (clk),
        .i_rst_n          (rst_n),
        .i_en             (i_en),
        .i_wr_en_a        (wr_en_a),
        .i_a_wdata        (a_wdata),
        .o_fifo_a_full    (fifo_a_full),
        .i_wr_en_b        (wr_en_b),
        .i_b_wdata        (b_wdata),
        .o_fifo_b_full    (fifo_b_full),
        .i_rd_en_sum      (rd_en_sum),
        .o_sum_data       (sum_data),
        .o_fifo_sum_empty (fifo_sum_empty),
        .o_dbg_rd_en      (dbg_rd_en),
        .o_dbg_acc_en     (dbg_acc_en),
        .o_dbg_acc_clr    (dbg_acc_clr),
        .o_dbg_sum_wr_en  (dbg_sum_wr_en)
    );

    initial clk = 1'b0;
    always #(Clkperiod/2) clk = ~clk;

    initial begin
        // $dumpfile("tb_mac_top_hexdata.vcd");
        // $dumpvars(0, tb_mac_top_hexdata);
    end

    // Task: 寫入一組 (a,b) 到 A_FIFO / B_FIFO
    task automatic write_pair;
        input [Datawidth-1:0] a_val;
        input [Datawidth-1:0] b_val;
        begin
            @(negedge clk);
            wr_en_a = 1'b1;
            wr_en_b = 1'b1;
            a_wdata = a_val;
            b_wdata = b_val;
            @(negedge clk);
            wr_en_a = 1'b0;
            wr_en_b = 1'b0;
        end
    endtask

    // Task: 從 Sum FIFO 讀出一筆結果，並與 golden 值比對 (自動 PASS/FAIL)
    task automatic read_and_check;
        input integer block_idx;
        input [Accwidth-1:0] golden_val;
        begin
            @(negedge clk);
            rd_en_sum = 1'b1;
            @(negedge clk);
            rd_en_sum = 1'b0;
            @(negedge clk);   // Non-FWFT，需等待 1 cycle 讓 dout 更新
            if (sum_data === golden_val) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS: Block %0d  DUT=%0d (0x%05h)  Golden=%0d (0x%05h)",
                           $time, block_idx, sum_data, sum_data, golden_val, golden_val);
            end else begin
                error_count = error_count + 1;
                $display("[%0t] FAIL: Block %0d  DUT=%0d (0x%05h)  Golden=%0d (0x%05h) <-- Fail!",
                           $time, block_idx, sum_data, sum_data, golden_val, golden_val);
            end
        end
    endtask

    initial begin
        rst_n     = 1'b0;
        i_en      = 1'b0;
        wr_en_a   = 1'b0;
        wr_en_b   = 1'b0;
        a_wdata   = 0;
        b_wdata   = 0;
        rd_en_sum = 1'b0;
        error_count = 0;
        pass_count  = 0;

        //////////////////// 讀入 hex 檔案 /////////////////
        // $readmemh 會依照檔案內容依序填入陣列，索引從 0 開始
        // 檔案筆數必須 >= Mblocks*N (A/B) 與 Mblocks (golden_sum)
        // 否則超出的陣列元素會維持 X (未定義)
        $display("[%0t] Read .hex files: %s, %s, %s", $time, Ahexfile, Bhexfile, Goldenhexfile);
        $readmemh(Ahexfile, a_mem);
        $readmemh(Bhexfile, b_mem);
        $readmemh(Goldenhexfile, gold_mem);

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        i_en  = 1'b1;
        repeat (2) @(posedge clk);

        //////////////////// 依序跑過每個 block，寫入資料並比對結果 /////////////////
        for (blk = 0; blk < Mblocks; blk = blk + 1) begin
            $display("\n---- Start to write Block %0d 's %0d nums of data ----", blk, N);
            for (idx = 0; idx < N; idx = idx + 1) begin
                write_pair(a_mem[blk*N + idx], b_mem[blk*N + idx]);
            end
            // 等待 pipeline 跑完 N 次累加並寫入 Sum FIFO
            repeat (N + 5) @(posedge clk);
            read_and_check(blk, gold_mem[blk]);
        end

        //////////////////// 結果總結 /////////////////
        repeat (5) @(posedge clk);
        $display("\n");
        $display("//////////////////////////////////////////////////////////");
        if (error_count == 0)
            $display("ALL %0d BLOCKS PASSED (tb_mac_top)", pass_count);
        else
            $display("%0d PASSED, %0d FAILED (tb_mac_top)", pass_count, error_count);
        $display("//////////////////////////////////////////////////////////");

        $finish;
    end

endmodule
