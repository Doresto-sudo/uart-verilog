// ============================================================================
// tb_uart.v
// ----------------------------------------------------------------------------
// Self-checking testbench for uart_top (loopback).
//
// Strategy:
//   - Use a small CLK_FREQ/BAUD ratio so each bit is only a handful of clocks;
//     this keeps simulation fast while exercising the identical RTL logic.
//   - Send a list of test bytes one at a time, waiting for tx_done before the
//     next, and capture each rx_valid byte.
//   - Compare received against sent; report PASS/FAIL per byte and overall.
//   - Dump a VCD waveform for inspection in GTKWave.
// ============================================================================
`timescale 1ns / 1ps

module tb_uart;

    // Small ratio for fast sim: 16 clocks/bit, oversample 16 -> 1 clk/os-tick.
    localparam integer CLK_FREQ_HZ = 1_600_000;
    localparam integer BAUD_RATE   = 100_000;
    localparam integer OVERSAMPLE  = 16;

    localparam integer CLK_PERIOD  = 20;   // ns -> 50 MHz sim clock edge rate

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg        start = 1'b0;
    reg  [7:0] tx_data = 8'h00;

    wire       tx_busy, tx_done;
    wire [7:0] rx_data;
    wire       rx_valid, rx_frame_err;
    wire       serial_line;

    // Device under test.
    uart_top #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE),
        .OVERSAMPLE  (OVERSAMPLE)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .tx_data      (tx_data),
        .tx_busy      (tx_busy),
        .tx_done      (tx_done),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_frame_err (rx_frame_err),
        .serial_line  (serial_line)
    );

    // Clock generation.
    always #(CLK_PERIOD/2) clk = ~clk;

    // Scoreboard counters.
    integer errors = 0;
    integer checks = 0;

    // Test vectors.
    reg [7:0] vectors [0:4];
    integer   i;

    // Capture received bytes asynchronously.
    reg [7:0] last_rx;
    reg       got_rx;
    always @(posedge clk) begin
        if (rx_valid) begin
            last_rx <= rx_data;
            got_rx  <= 1'b1;
        end
    end

    // Task: send one byte and wait for it to finish transmitting.
    task send_byte(input [7:0] b);
        begin
            @(posedge clk);
            tx_data <= b;
            start   <= 1'b1;
            @(posedge clk);
            start   <= 1'b0;
            // Wait for the transmitter to assert then deassert busy.
            wait (tx_busy == 1'b1);
            wait (tx_busy == 1'b0);
        end
    endtask

    initial begin
        $dumpfile("sim/uart_tb.vcd");
        $dumpvars(0, tb_uart);

        vectors[0] = 8'h41; // 'A'
        vectors[1] = 8'h55; // 0101_0101
        vectors[2] = 8'hAA; // 1010_1010
        vectors[3] = 8'hFF; // all ones
        vectors[4] = 8'h00; // all zeros

        // Reset.
        rst_n  = 1'b0;
        got_rx = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("=========================================================");
        $display(" UART loopback self-test");
        $display("=========================================================");

        for (i = 0; i < 5; i = i + 1) begin
            got_rx = 1'b0;
            send_byte(vectors[i]);

            // Wait for the receiver to deliver the byte (with a timeout).
            wait (got_rx == 1'b1);

            checks = checks + 1;
            if (last_rx === vectors[i] && rx_frame_err === 1'b0) begin
                $display("  [PASS] sent 0x%02h  received 0x%02h", vectors[i], last_rx);
            end else begin
                errors = errors + 1;
                $display("  [FAIL] sent 0x%02h  received 0x%02h  frame_err=%b",
                         vectors[i], last_rx, rx_frame_err);
            end
        end

        $display("=========================================================");
        if (errors == 0)
            $display(" RESULT: ALL %0d CHECKS PASSED", checks);
        else
            $display(" RESULT: %0d / %0d CHECKS FAILED", errors, checks);
        $display("=========================================================");

        repeat (20) @(posedge clk);
        $finish;
    end

    // Global timeout so a broken design can't hang the sim forever.
    initial begin
        #5_000_000;
        $display(" [TIMEOUT] simulation exceeded time budget");
        $finish;
    end

endmodule
