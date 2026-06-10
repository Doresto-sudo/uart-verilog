// ============================================================================
// uart_top.v
// ----------------------------------------------------------------------------
// Top-level UART wrapper that instantiates the baud generator, transmitter,
// and receiver, and connects TX directly to RX (internal loopback).
//
// This is the synthesizable top: drive `start`/`tx_data` to send a byte, and
// the same byte appears on `rx_data` with `rx_valid` after it loops back
// through the serial line. Useful as a self-test on real hardware and as the
// device-under-test for the simulation testbench.
// ============================================================================
`timescale 1ns / 1ps

module uart_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115200,
    parameter integer OVERSAMPLE  = 16
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_data,
    output wire       tx_busy,
    output wire       tx_done,
    output wire [7:0] rx_data,
    output wire       rx_valid,
    output wire       rx_frame_err,
    output wire       serial_line   // exposed for observation / external wiring
);

    wire tx_tick, rx_tick;
    wire tx_line;

    assign serial_line = tx_line;

    baud_gen #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE),
        .OVERSAMPLE  (OVERSAMPLE)
    ) u_baud (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_tick (tx_tick),
        .rx_tick (rx_tick)
    );

    uart_tx u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_tick (tx_tick),
        .start   (start),
        .data    (tx_data),
        .tx      (tx_line),
        .busy    (tx_busy),
        .done    (tx_done)
    );

    uart_rx #(
        .OVERSAMPLE (OVERSAMPLE)
    ) u_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_tick   (rx_tick),
        .rx        (tx_line),       // loopback: TX feeds RX
        .data      (rx_data),
        .valid     (rx_valid),
        .frame_err (rx_frame_err)
    );

endmodule
