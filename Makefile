# ============================================================================
# Makefile - UART (Verilog) simulation
#
#   make          build and run the self-checking testbench
#   make wave     open the VCD in GTKWave
#   make clean    remove generated artefacts
#
# Requires: iverilog, vvp (Icarus Verilog). Optional: gtkwave.
# ============================================================================

RTL  := rtl/baud_gen.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v
TB   := tb/tb_uart.v
SIM  := sim/uart_sim
VCD  := sim/uart_tb.vcd

.PHONY: all run wave clean

all: run

$(SIM): $(RTL) $(TB)
	iverilog -g2012 -Wall -o $(SIM) $(RTL) $(TB)

run: $(SIM)
	vvp $(SIM)

wave: $(VCD)
	gtkwave $(VCD) &

clean:
	rm -f $(SIM) $(VCD)
