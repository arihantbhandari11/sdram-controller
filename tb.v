`timescale 1ns/1ps

module sdram_controller_tb;

    // ============================================================
    // HOST SIDE
    // ============================================================
    reg  [23:0] haddr;
    reg  [15:0] data_input;
    wire [15:0] data_output;

    reg  rd_enable;
    reg  wr_enable;
    reg  rst_n;
    reg  clk;

    wire rd_ready;
    wire busy;

    // ============================================================
    // SDRAM SIDE
    // ============================================================
    wire [12:0] addr;
    wire [1:0]  bank_addr;
    wire [15:0] data;

    wire clock_enable;
    wire cs_n;
    wire ras_n;
    wire cas_n;
    wire we_n;
    wire data_mask_low;
    wire data_mask_high;

    // ============================================================
    // Simple SDRAM data model
    // ============================================================
    reg [15:0] data_r;
    assign data = data_r;

    // SDRAM read data model.
    // The DUT samples `data` on the posedge that ENDS READ_READ.
    // We drive BBBB during READ_CAS, and hold it through
    // READ_NOP2 and READ_READ. Then release to Z.
    always @(posedge clk) begin
        if (dut.state == 5'b10010)        // READ_CAS -> next is READ_NOP2
            data_r <= 16'hBBBB;
        else if (dut.state != 5'b10011 && dut.state != 5'b10100)
            data_r <= 16'hzzzz;
        // hold BBBB through READ_NOP2 and READ_READ
    end

    // ============================================================
    // DUT
    // ============================================================
    sdram_controller dut (
        .wr_addr          (haddr),
        .wr_data          (data_input),
        .wr_enable        (wr_enable),

        .rd_addr          (haddr),
        .rd_data          (data_output),
        .rd_ready         (rd_ready),
        .rd_enable        (rd_enable),

        .busy             (busy),
        .rst_n            (rst_n),
        .clk              (clk),

        .addr             (addr),
        .bank_addr        (bank_addr),
        .data             (data),
        .clock_enable     (clock_enable),
        .cs_n             (cs_n),
        .ras_n            (ras_n),
        .cas_n            (cas_n),
        .we_n             (we_n),
        .data_mask_low    (data_mask_low),
        .data_mask_high   (data_mask_high)
    );

    // ============================================================
    // CLOCK
    // Controller default is 133 MHz.
    // Period ~= 7.519 ns.
    // ============================================================
    initial clk = 1'b0;
    always #3.7594 clk = ~clk;

    // ============================================================
    // INITIAL VALUES
    // ============================================================
    initial begin
        haddr      = 24'h000000;
        data_input = 16'h0000;
        rd_enable  = 1'b0;
        wr_enable  = 1'b0;
        rst_n      = 1'b1;
        data_r     = 16'hzzzz;
    end

    // ============================================================
    // TEST SEQUENCE
    // ============================================================
    initial begin

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------
        #10;
        rst_n = 1'b0;

        // Hold reset for several clock cycles
        repeat (3) @(posedge clk);

        rst_n = 1'b1;

        $display("================================================");
        $display("RESET RELEASED");
        $display("Time = %0t", $time);
        $display("================================================");

        // --------------------------------------------------------
        // Wait until the actual internal FSM reaches IDLE.
        // --------------------------------------------------------
        wait (dut.state == 5'b00000);

        $display("SDRAM INITIALIZATION COMPLETE");
        $display("Time = %0t", $time);

        // Give one extra clock before issuing a host request.
        @(posedge clk);

        // ========================================================
        // WRITE TEST
        // ========================================================
        $display("================================================");
        $display("WRITE TEST");
        $display("Time = %0t", $time);

        haddr      = 24'hFEDBED;
        data_input = 16'h0D05;

        // FIX: Drive inputs on negedge to avoid race conditions
        @(negedge clk);
        wr_enable = 1'b1;

        @(negedge clk);
        wr_enable = 1'b0;

        $display("WRITE REQUEST SENT");
        $display("Address = %h", haddr);
        $display("Data    = %h", data_input);
        $display("Time    = %0t", $time);

        // Wait until WRITE transaction returns to IDLE.
        wait (dut.state == 5'b00000);
        @(posedge clk);

        $display("WRITE TRANSACTION COMPLETE");
        $display("Time    = %0t", $time);

        // ========================================================
        // READ TEST
        // ========================================================
        $display("================================================");
        $display("READ TEST");
        $display("Time = %0t", $time);

        haddr = 24'hBEDFED;

        // FIX: Drive inputs on negedge to avoid race conditions
        @(negedge clk);
        rd_enable = 1'b1;

        @(negedge clk);
        rd_enable = 1'b0;

        $display("READ REQUEST SENT");
        $display("Address = %h", haddr);
        $display("Time    = %0t", $time);

        // --------------------------------------------------------
        // The SDRAM data model now handles driving BBBB
        // automatically. Wait for the controller to capture it.
        // --------------------------------------------------------
        wait (rd_ready === 1'b1);
        #1;

        $display("================================================");
        $display("READ RESULT");
        $display("data_output = %h", data_output);
        $display("rd_ready    = %b", rd_ready);
        $display("Time        = %0t", $time);
        $display("================================================");

        // ========================================================
        // PASS / FAIL CHECK
        // ========================================================
        if (data_output === 16'hBBBB)
            $display("READ DATA CHECK: PASS");
        else
            $display("READ DATA CHECK: FAIL");

        if (rd_ready === 1'b1)
            $display("RD_READY CHECK: PASS");
        else
            $display("RD_READY CHECK: FAIL");

        // Allow waveform inspection.
        #100;

        $display("================================================");
        $display("SIMULATION FINISHED");
        $display("================================================");

        $finish;
    end

endmodule
