// ============================================================================
// uart_rx.v
// ----------------------------------------------------------------------------
// UART receiver (8-N-1) with 16x oversampling and mid-bit sampling.
//
// The receiver watches the idle-high line for a falling edge (start bit).
// It then counts oversample ticks: it samples each bit at tick 7 (the centre
// of a 16-tick bit window) so small baud mismatches don't push the sample
// point off the bit. After 8 data bits it checks the stop bit and pulses
// `valid` with the assembled byte on `data`.
//
// A two-flop synchroniser guards against metastability on the async `rx` pin.
// ============================================================================
`timescale 1ns / 1ps

module uart_rx #(
    parameter integer OVERSAMPLE = 16
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_tick,   // OVERSAMPLE pulses per bit period
    input  wire       rx,        // serial input line (asynchronous)
    output reg  [7:0] data,      // received byte
    output reg        valid,     // 1-cycle pulse when `data` is ready
    output reg        frame_err  // high if stop bit was not 1
);

    localparam integer HALF = OVERSAMPLE / 2;          // mid-bit sample point
    localparam integer OSW  = $clog2(OVERSAMPLE);

    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0]     state;
    reg [OSW-1:0] os_cnt;    // counts oversample ticks within a bit
    reg [2:0]     bit_idx;   // which data bit
    reg [7:0]     shifter;

    // Two-flop synchroniser for the incoming line.
    reg rx_meta, rx_sync;
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            os_cnt    <= {OSW{1'b0}};
            bit_idx   <= 3'd0;
            shifter   <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            valid <= 1'b0;   // default: deassert pulse

            if (rx_tick) begin
                case (state)
                    // ----------------------------------------------------
                    S_IDLE: begin
                        frame_err <= 1'b0;
                        if (rx_sync == 1'b0) begin   // falling edge = start
                            os_cnt <= {OSW{1'b0}};
                            state  <= S_START;
                        end
                    end

                    // ----------------------------------------------------
                    // Confirm the start bit is still low at its centre;
                    // this rejects narrow glitches on the line.
                    S_START: begin
                        if (os_cnt == HALF - 1) begin
                            if (rx_sync == 1'b0) begin
                                os_cnt  <= {OSW{1'b0}};
                                bit_idx <= 3'd0;
                                state   <= S_DATA;
                            end else begin
                                state <= S_IDLE;   // false start
                            end
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end

                    // ----------------------------------------------------
                    // Sample each data bit at the centre of its window.
                    S_DATA: begin
                        if (os_cnt == OVERSAMPLE - 1) begin
                            os_cnt  <= {OSW{1'b0}};
                            shifter <= {rx_sync, shifter[7:1]};  // LSB first
                            if (bit_idx == 3'd7)
                                state <= S_STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end

                    // ----------------------------------------------------
                    S_STOP: begin
                        if (os_cnt == OVERSAMPLE - 1) begin
                            data      <= shifter;
                            valid     <= 1'b1;
                            frame_err <= (rx_sync != 1'b1); // stop must be 1
                            state     <= S_IDLE;
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
