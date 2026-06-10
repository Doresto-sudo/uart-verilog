// ============================================================================
// baud_gen.v
// ----------------------------------------------------------------------------
// Baud-rate tick generator.
//
// Produces two strobes from the system clock:
//   - tx_tick : one pulse per bit period          (used to shift TX bits out)
//   - rx_tick : one pulse per (1/OVERSAMPLE) bit   (used to oversample RX)
//
// OVERSAMPLE is conventionally 16 for UART receivers: the receiver counts
// oversample ticks so it can sample each incoming bit near its centre, which
// tolerates small clock-frequency mismatches between transmitter and receiver.
//
// DIVISOR = CLK_FREQ_HZ / BAUD_RATE  gives the number of clock cycles per bit.
// The rx tick divisor is DIVISOR / OVERSAMPLE.
// ============================================================================
`timescale 1ns / 1ps

module baud_gen #(
    parameter integer CLK_FREQ_HZ = 50_000_000, // system clock frequency
    parameter integer BAUD_RATE   = 115200,     // target baud
    parameter integer OVERSAMPLE  = 16          // RX oversampling factor
) (
    input  wire clk,
    input  wire rst_n,      // active-low synchronous reset
    output reg  tx_tick,    // 1-cycle pulse, once per bit period
    output reg  rx_tick     // 1-cycle pulse, OVERSAMPLE times per bit period
);

    // Number of clock cycles in one full bit, and in one oversample slot.
    localparam integer BIT_DIV = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer OS_DIV  = BIT_DIV / OVERSAMPLE;

    // Counter widths sized to hold the divisors.
    // Guard against $clog2 returning 0 when a divisor is 1.
    localparam integer BIT_W = (BIT_DIV > 1) ? $clog2(BIT_DIV) : 1;
    localparam integer OS_W  = (OS_DIV  > 1) ? $clog2(OS_DIV)  : 1;

    reg [BIT_W-1:0] tx_cnt;
    reg [OS_W-1:0]  os_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_cnt  <= {BIT_W{1'b0}};
            os_cnt  <= {OS_W{1'b0}};
            tx_tick <= 1'b0;
            rx_tick <= 1'b0;
        end else begin
            // ---- TX bit-period tick ----
            if (tx_cnt == BIT_DIV - 1) begin
                tx_cnt  <= {BIT_W{1'b0}};
                tx_tick <= 1'b1;
            end else begin
                tx_cnt  <= tx_cnt + 1'b1;
                tx_tick <= 1'b0;
            end

            // ---- RX oversample tick ----
            if (os_cnt == OS_DIV - 1) begin
                os_cnt  <= {OS_W{1'b0}};
                rx_tick <= 1'b1;
            end else begin
                os_cnt  <= os_cnt + 1'b1;
                rx_tick <= 1'b0;
            end
        end
    end

endmodule
