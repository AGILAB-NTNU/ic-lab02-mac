// =============================================================================
// Testbench: tb_mac_control_fsm_hex
// Purpose:
//   Verify mac_control_fsm with the same Python-generated dataset used by
//   tb_mac_top.
//
// Method:
//   1. Load input_A.hex / input_B.hex / golden_sum.hex.
//   2. Use rd_en to model reads from pseudo A/B FIFOs.
//   3. Delay the read data by one clock so acc_en operates on the modeled
//      synchronous-FIFO output.
//   4. Use acc_en / acc_clr to drive a testbench scoreboard accumulator.
//   5. Whenever sum_wr_en is asserted, compare the scoreboard accumulator
//      with golden_sum.hex.
//
// This lets a control-only FSM be checked against numerical golden results
// without adding datapath ports to the DUT.
// =============================================================================
`timescale 1ns/1ps

module tb_mac_control_fsm;

    // Keep these values consistent with tb_mac_top.sv and generate_golden.py.
    localparam integer Mblocks = 5;
    localparam integer N = 10;
    localparam integer Datawidth = 8;
    localparam integer Accwidth = 32;
    localparam integer Clkperiod = 8;
    localparam integer Totaldata = Mblocks * N;
    localparam integer Maxcycles = Totaldata * 10 + 200;

    localparam string Ahexfile = "input_A.hex";
    localparam string Bhexfile = "input_B.hex";
    localparam string Goldenhexfile = "golden_sum.hex";

    // DUT inputs use the same naming as mac_control_fsm.sv.
    reg i_clk;
    reg i_rst_n;
    reg i_en;
    wire i_fifo_A_empty;
    wire i_fifo_B_empty;
    reg  i_fifo_sum_full;

    // DUT outputs use the same naming as mac_control_fsm.sv.
    wire o_rd_en;
    wire o_acc_en;
    wire o_acc_clr;
    wire o_sum_wr_en;

    // Python-generated test vectors.
    reg [Datawidth-1:0] a_mem    [Totaldata];
    reg [Datawidth-1:0] b_mem    [Totaldata];
    reg [Accwidth-1:0]  gold_mem [Mblocks];

    // Pseudo synchronous-FIFO outputs.
    reg [Datawidth-1:0] fifo_A_dout_model;
    reg [Datawidth-1:0] fifo_B_dout_model;
    reg ifo_dout_valid;

    // Scoreboard accumulator. It follows only the control signals generated
    // by the DUT, so a wrong read/accumulate/write sequence causes a mismatch.
    reg [Accwidth-1:0] model_acc;
    wire [(2*Datawidth)-1:0] model_product;

    integer rd_ptr;
    integer block_idx;
    integer pass_count;
    integer error_count;
    integer file_error_count;
    integer idx;
    integer cycle_count;

    reg force_input_empty;
    reg request_output_stall;

    assign model_product = fifo_A_dout_model * fifo_B_dout_model;

    assign i_fifo_A_empty = force_input_empty || (rd_ptr >= Totaldata);
    assign i_fifo_B_empty = force_input_empty || (rd_ptr >= Totaldata);

    // -------------------------------------------------------------------------
    // DUT: mac_control_fsm.sv
    // -------------------------------------------------------------------------
    mac_control_fsm #(
        .N (N)
    ) dut (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_en            (i_en),
        .i_fifo_A_empty  (i_fifo_A_empty),
        .i_fifo_B_empty  (i_fifo_B_empty),
        .i_fifo_sum_full (i_fifo_sum_full),
        .o_rd_en         (o_rd_en),
        .o_acc_en        (o_acc_en),
        .o_acc_clr       (o_acc_clr),
        .o_sum_wr_en     (o_sum_wr_en)
    );

    initial i_clk = 1'b0;
    always #(Clkperiod/2) i_clk = ~i_clk;

    // -------------------------------------------------------------------------
    // Pseudo FIFO + numerical scoreboard.
    //
    // mac_control_fsm registers o_acc_en <= o_rd_en. Therefore a read at one
    // clock edge updates the pseudo FIFO output, and the corresponding product
    // is consumed by o_acc_en on the following clock edge.
    // -------------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            rd_ptr            <= 0;
            block_idx         <= 0;
            fifo_A_dout_model <= {Datawidth{1'b0}};
            fifo_B_dout_model <= {Datawidth{1'b0}};
            fifo_dout_valid   <= 1'b0;
            model_acc         <= {Accwidth{1'b0}};
        end else begin
            // Control invariants from the current FSM RTL.
            if (o_sum_wr_en !== o_acc_clr) begin
                error_count = error_count + 1;
                $display("[%0t] FAIL: o_sum_wr_en(%b) != o_acc_clr(%b)",
                         $time, o_sum_wr_en, o_acc_clr);
            end

            if (o_rd_en && (i_fifo_A_empty || i_fifo_B_empty)) begin
                error_count = error_count + 1;
                $display("[%0t] FAIL: o_rd_en asserted while input FIFO empty",
                         $time);
            end

            if (o_sum_wr_en && i_fifo_sum_full) begin
                error_count = error_count + 1;
                $display("[%0t] FAIL: o_sum_wr_en asserted while Sum FIFO full",
                         $time);
            end

            if (o_acc_en && !fifo_dout_valid) begin
                error_count = error_count + 1;
                $display("[%0t] FAIL: o_acc_en asserted without valid FIFO data",
                         $time);
            end

            // A write pulse means one MAC block is complete. Compare the result
            // before model_acc is cleared on this same clock edge.
            if (o_sum_wr_en) begin
                if (block_idx >= Mblocks) begin
                    error_count = error_count + 1;
                    $display("[%0t] FAIL: extra o_sum_wr_en after all blocks", $time);
                end else if (model_acc === gold_mem[block_idx]) begin
                    pass_count = pass_count + 1;
                    $display("[%0t] PASS: Block %0d Model=0x%08h Golden=0x%08h",
                             $time, block_idx, model_acc, gold_mem[block_idx]);
                end else begin
                    error_count = error_count + 1;
                    $display("[%0t] FAIL: Block %0d Model=0x%08h Golden=0x%08h",
                             $time, block_idx, model_acc, gold_mem[block_idx]);
                end
                block_idx <= block_idx + 1;
            end

            // Same clear/enable priority as mac_accum.sv.
            if (o_acc_clr && o_acc_en)
                model_acc <= {{(Accwidth-(2*Datawidth)){1'b0}}, model_product};
            else if (o_acc_clr)
                model_acc <= {Accwidth{1'b0}};
            else if (o_acc_en)
                model_acc <= model_acc
                           + {{(Accwidth-(2*Datawidth)){1'b0}}, model_product};

            // Non-FWFT / synchronous FIFO model.
            if (o_rd_en && !i_fifo_A_empty && !i_fifo_B_empty) begin
                fifo_A_dout_model <= a_mem[rd_ptr];
                fifo_B_dout_model <= b_mem[rd_ptr];
                rd_ptr            <= rd_ptr + 1;
                fifo_dout_valid   <= 1'b1;
            end else begin
                fifo_dout_valid   <= 1'b0;
            end
        end
    end

    // Optional output-full stall. Wait until the FSM has consumed exactly the
    // first block, then keep the Sum FIFO full long enough to hold Waitout.
    initial begin
        request_output_stall = 1'b0;
        wait (i_rst_n === 1'b1);
        wait (rd_ptr >= N);
        request_output_stall = 1'b1;
        repeat (4) @(posedge i_clk);
        request_output_stall = 1'b0;
    end

    always_comb begin
        i_fifo_sum_full = request_output_stall;
    end

    initial begin
        i_rst_n           = 1'b0;
        i_en              = 1'b0;
        force_input_empty = 1'b0;

        pass_count        = 0;
        error_count       = 0;
        file_error_count  = 0;
        cycle_count       = 0;

        // ---------------------------------------------------------------------
        // Load Python-generated files.
        // ---------------------------------------------------------------------
        $display("[%0t] Loading %s, %s, %s",
                 $time, Ahexfile, Bhexfile, Goldenhexfile);

        $readmemh(Ahexfile,      a_mem);
        $readmemh(Bhexfile,      b_mem);
        $readmemh(Goldenhexfile, gold_mem);

        for (idx = 0; idx < Totaldata; idx = idx + 1) begin
            if (^a_mem[idx] === 1'bx) begin
                file_error_count = file_error_count + 1;
                $display("FILE ERROR: a_mem[%0d] is X", idx);
            end
            if (^b_mem[idx] === 1'bx) begin
                file_error_count = file_error_count + 1;
                $display("FILE ERROR: b_mem[%0d] is X", idx);
            end
        end

        for (idx = 0; idx < Mblocks; idx = idx + 1) begin
            if (^gold_mem[idx] === 1'bx) begin
                file_error_count = file_error_count + 1;
                $display("FILE ERROR: gold_mem[%0d] is X", idx);
            end
        end

        if (file_error_count != 0) begin
            $display("\nTEST ABORTED: %0d HEX FILE ERROR(S)", file_error_count);
            $finish;
        end

        // ---------------------------------------------------------------------
        // Reset and enable FSM.
        // mac_control_fsm state/counter reset is sampled on posedge i_clk.
        // ---------------------------------------------------------------------
        repeat (3) @(posedge i_clk);
        @(negedge i_clk);
        i_rst_n = 1'b1;

        // With i_en=0, no read is allowed.
        repeat (2) begin
            @(posedge i_clk);
            #1;
            if (o_rd_en !== 1'b0) begin
                error_count = error_count + 1;
                $display("[%0t] FAIL: o_rd_en must stay 0 while i_en=0", $time);
            end
        end

        @(negedge i_clk);
        i_en = 1'b1;

        // Input-empty stall in the first block.
        wait (rd_ptr >= 4);
        @(negedge i_clk);
        force_input_empty = 1'b1;
        repeat (3) @(posedge i_clk);
        @(negedge i_clk);
        force_input_empty = 1'b0;

        // Wait for all blocks or timeout.
        while ((block_idx < Mblocks) && (cycle_count < Maxcycles)) begin
            @(posedge i_clk);
            cycle_count = cycle_count + 1;
        end

        repeat (3) @(posedge i_clk);

        if (block_idx != Mblocks) begin
            error_count = error_count + 1;
            $display("FAIL: Timeout. Completed %0d/%0d blocks, rd_ptr=%0d/%0d",
                     block_idx, Mblocks, rd_ptr, Totaldata);
        end

        if (rd_ptr != Totaldata) begin
            error_count = error_count + 1;
            $display("FAIL: FSM consumed %0d input pairs; expected %0d",
                     rd_ptr, Totaldata);
        end

        $display("\n==========================================================");
        if (error_count == 0)
            $display("ALL %0d BLOCKS PASSED (tb_mac_control_fsm)", pass_count);
        else
            $display("%0d BLOCK(S) PASSED, %0d ERROR(S) (tb_mac_control_fsm)",
                     pass_count, error_count);
        $display("==========================================================");

        $finish;
    end

endmodule
