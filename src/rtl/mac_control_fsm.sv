// verilog_lint: waive-start
//////////////////////////////////////////////////////////////////////////////////
// Company: AGILAB
// Engineer: Undergraduate Student
//
// Create Date: 2026/08/13 11:10:22
// Design Type: RTL (Synthesizable Circuit)
// Design Name: ic-lab02-mac
// Module Name: mac_control_fsm
// Project Name:
// Target Devices:
// Tool Versions:
// Description: 建立乘法累加器（MAC）的控制單元。
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

module mac_control_fsm #(
    parameter integer N = 10   // 每個 block 需要累加的次數
) (
    input wire i_clk,
    input wire i_rst_n,
    input wire i_en,
    input wire i_fifo_A_empty,
    input wire i_fifo_B_empty,
    input wire i_fifo_sum_full,

    output reg o_rd_en,     // A/B FIFO 同步讀取致能
    output reg o_acc_en,    // Acc 累加致能 (o_rd_en 延遲一拍)
    output reg o_acc_clr,   // Acc 清零 (與 o_sum_wr_en 同拍)
    output reg o_sum_wr_en  // Sum FIFO 寫入致能
);

    localparam integer Countwidth = (N <= 1) ? 1 : $clog2(N+1);
    localparam logic [2:0]
        Idle = 3'b000,
        Read = 3'b001,
        Accum = 3'b010,
        Waitout = 3'b011,
        Write = 3'b100;
    reg [Countwidth-1:0] acc_cnt_r;
    reg [2:0] state_r, next_state_r;

    // State Register
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            state_r <= Idle;
        end else begin
            state_r <= next_state_r;
        end
    end

    // Next state logic
    always_comb begin : NextStatelogic
        next_state_r = state_r;  // 預設值
        case (state_r)
            Idle: begin
                if (i_en)
                    next_state_r = Read;
            end

            Read: begin
                if (!i_fifo_A_empty && !i_fifo_B_empty) begin
                    next_state_r = Accum;
                end
            end

            Accum: begin
                if (acc_cnt_r == N)
                    next_state_r = Waitout;
                else
                    next_state_r = Read;
            end

            Waitout: begin
                // 後端 FIFO 沒有滿時，才允許寫入
                if (!i_fifo_sum_full)
                    next_state_r = Write;
            end

            Write: begin
                // 寫入只要一拍，完成後回到 Idle
                next_state_r = Idle;
            end

            default: next_state_r = Idle;
        endcase
    end

    // Datapath: counter
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            acc_cnt_r <= {Countwidth{1'b0}};
        end else begin
            if (state_r == Write) begin
                acc_cnt_r <= {Countwidth{1'b0}};
            end else if (state_r == Read && !i_fifo_A_empty && !i_fifo_B_empty) begin
                acc_cnt_r <= acc_cnt_r + 1'b1;
            end
        end
    end

    // Output logic
    always_comb begin : Outputlogic
        // 初始化預設值
        o_rd_en = 1'b0;
        o_sum_wr_en = 1'b0;
        o_acc_clr = 1'b0;
        // o_acc_en = 1'b0;

        case (state_r)
            Read: begin
                if (!i_fifo_A_empty && !i_fifo_B_empty)
                    o_rd_en = 1'b1;
            end

            Write: begin
                o_sum_wr_en = 1'b1;
                o_acc_clr = 1'b1;
            end

            default: begin
                // 保持為 0
            end
        endcase
    end

    // Acc register
    always @(posedge i_clk) begin
        if (!i_rst_n)
            o_acc_en <= 1'b0;
        else
            o_acc_en <= o_rd_en;
    end

endmodule

