// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/12 15:37:14
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic_lab02_mac
// Module Name: sync_fifo
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立資料位元寬度為DATA_WIDTH參數 深度為DEPTH參數的fifo
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

module sync_fifo #(
    parameter int DATA_WIDTH = 32, // 資料位元寬度
    parameter int DEPTH      = 8   // fifo深度
)(
    input wire i_clk,   // 時脈
    input wire i_rst_n, // 重置訊號(低有效)

    input wire i_wren,                 // 寫入使能
    input wire [DATA_WIDTH-1:0] i_data, // 寫入資料
    output wire o_full,                // FIFO已滿

    input wire i_rden,                     // 讀出使能
    output reg [DATA_WIDTH-1:0] o_data,    // 讀出資料
    output reg o_data_vld,               // 讀出資料有效
    output wire o_empty                    // FIFO為空
);

    // 自動根據深度計算指標與計數器的位元寬度
    localparam int AddrWidth  = $clog2(DEPTH);     // 記憶體位址位元數
    localparam int CountWidth = $clog2(DEPTH + 1); // 資料計數器位元數

    // 內部記憶體陣列與暫存器宣告
    reg [DATA_WIDTH-1:0] mem [DEPTH]; // 內部 RAM/ Register 陣列
    reg [AddrWidth-1:0]  wr_ptr_r;    // 寫入指標
    reg [AddrWidth-1:0]  rd_ptr_r;    // 讀取指標
    reg [CountWidth-1:0] count_r;     // 當前 FIFO 內資料總筆數計數器

    wire do_write; // 成功寫入訊號
    wire do_read;  // 成功讀取訊號

    // 判斷 Empty 與 Full 狀態
    assign o_full  = (count_r == DEPTH[CountWidth-1:0]);
    assign o_empty = (count_r == '0);

    // 只有在致能拉高且 FIFO 允許操作時才真正執行讀寫
    assign do_write = i_wren && !o_full;
    assign do_read  = i_rden && !o_empty;

    // 指標、狀態與資料更新
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            // 系統重置：清空所有指標與輸出
            wr_ptr_r     <= '0;
            rd_ptr_r     <= '0;
            count_r      <= '0;
            o_data       <= '0;
            o_data_vld <= 1'b0;
        end else begin
            // 讀取成功後的下一個時脈週期拉高
            o_data_vld <= do_read;

            // 寫入處理邏輯
            if (do_write) begin
                mem[wr_ptr_r] <= i_data; // 寫入資料至當前指標位址

                // 寫入指標遞增與環形歸零
                if (wr_ptr_r == (DEPTH-1))
                    wr_ptr_r <= '0;
                else
                    wr_ptr_r <= wr_ptr_r + 1'b1;
            end

            // 讀取處理邏輯
            if (do_read) begin
                o_data <= mem[rd_ptr_r]; // 讀出資料登錄至輸出暫存器

                // 讀取指標遞增與環形歸零
                if (rd_ptr_r == (DEPTH-1))
                    rd_ptr_r <= '0;
                else
                    rd_ptr_r <= rd_ptr_r + 1'b1;
            end

            // 更新 FIFO 內部資料總筆數計數器
            case ({do_write, do_read})
                2'b10: begin // 僅寫入成功 -> 筆數 +1
                    count_r <= count_r + 1'b1;
                end

                2'b01: begin // 僅讀出成功 -> 筆數 -1
                    count_r <= count_r - 1'b1;
                end

                default: begin // 未操作、或同時成功讀寫 -> 筆數保持不變
                    count_r <= count_r;
                end
            endcase
        end
    end

endmodule
