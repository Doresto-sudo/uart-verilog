// ============================================================================
// uart_tx.v
// ----------------------------------------------------------------------------
// UART transmitter (8-N-1 framing: 8 data bits, no parity, 1 stop bit).
//
// Handshake:
//   - Assert `start` for one cycle with `data` valid to begin a transmission.
//   - `busy` is high for the whole frame; `start` is ignored while busy.
//   - `done` pulses for one cycle when the stop bit completes.
//
// The line idles high. A frame is: START(0), D0..D7 (LSB first), STOP(1).
// Bits advance on `tx_tick` from the baud generator.
// ============================================================================
`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_tick,   // one pulse per bit period
    input  wire       start,     // request to send `data`
    input  wire [7:0] data,      // byte to transmit
    output reg        tx,        // serial output line
    output reg        busy,      // high while a frame is in flight
    output reg        done       // 1-cycle pulse at end of frame
);

    // FSM states.
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg [2:0] bit_idx;   // which data bit (0..7)
    reg [7:0] shifter;   // holds the byte while shifting out

    always @(posedge clk) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            tx      <= 1'b1;   // idle line is high
            busy    <= 1'b0;
            done    <= 1'b0;
            bit_idx <= 3'd0;
            shifter <= 8'd0;
        end else begin
            done <= 1'b0;      // default: deassert pulse

            case (state)
                // --------------------------------------------------------
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        shifter <= data;   // latch the byte
                        busy    <= 1'b1;
                        state   <= S_START;
                    end
                end

                // --------------------------------------------------------
                S_START: begin
                    if (tx_tick) begin
                        tx      <= 1'b0;   // start bit
                        bit_idx <= 3'd0;
                        state   <= S_DATA;
                    end
                end

                // --------------------------------------------------------
                S_DATA: begin
                    if (tx_tick) begin
                        tx <= shifter[0];           // LSB first
                        shifter <= {1'b0, shifter[7:1]};
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end
                end

                // --------------------------------------------------------
                S_STOP: begin
                    if (tx_tick) begin
                        tx    <= 1'b1;   // stop bit
                        done  <= 1'b1;
                        busy  <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
