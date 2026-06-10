# UART Transmitter / Receiver in Verilog

A synthesizable UART (Universal Asynchronous Receiver/Transmitter) implemented
in Verilog, with a configurable baud-rate generator, a 16x-oversampling
receiver, and a **self-checking testbench** that verifies byte-level loopback
in simulation.

The design is written as a set of small, independently readable RTL modules —
a baud generator, a transmitter FSM, and a receiver FSM — wired together in a
loopback top so the whole datapath can be exercised end to end.

## Demo

The testbench transmits five bytes and checks that each is received correctly
through the internal TX→RX loopback. Below is the simulated timing for the
first byte, `0x41` (`'A'`), showing the start bit, eight data bits sent
LSB-first, and the stop bit, with `tx_busy` framing the transmission and
`rx_valid` pulsing when the byte is recovered:

![UART loopback waveform](docs/Waveform.jpg)

Simulation transcript:

```
=========================================================
 UART loopback self-test
=========================================================
  [PASS] sent 0x41  received 0x41
  [PASS] sent 0x55  received 0x55
  [PASS] sent 0xaa  received 0xaa
  [PASS] sent 0xff  received 0xff
  [PASS] sent 0x00  received 0x00
=========================================================
 RESULT: ALL 5 CHECKS PASSED
=========================================================
```

## Framing

Standard **8-N-1**: one start bit (line driven low), 8 data bits LSB-first, one
stop bit (line driven high). The line idles high.

## Architecture

```
            start, tx_data[7:0]
                   │
                   ▼
          ┌─────────────────┐   tx_tick   ┌──────────────┐
          │    uart_tx      │◀────────────│              │
          │   (TX FSM)      │             │   baud_gen   │
          └────────┬────────┘   rx_tick   │  (divider +  │
                   │ tx        ┌──────────▶│  oversample) │
                   │           │           └──────────────┘
                   ▼           │
          ┌─────────────────┐  │
          │    uart_rx      │◀─┘
          │   (RX FSM,      │
          │  16x oversample)│──▶ rx_data[7:0], rx_valid, frame_err
          └─────────────────┘
```

| Module        | File              | Role                                                       |
|---------------|-------------------|------------------------------------------------------------|
| `baud_gen`    | `rtl/baud_gen.v`  | Divides the system clock into a TX bit tick and a 16x RX oversample tick. |
| `uart_tx`     | `rtl/uart_tx.v`   | 4-state FSM (IDLE/START/DATA/STOP) that shifts a byte out LSB-first. |
| `uart_rx`     | `rtl/uart_rx.v`   | Oversampling FSM that samples each bit at its centre; includes a two-flop synchroniser and a stop-bit frame check. |
| `uart_top`    | `rtl/uart_top.v`  | Wires the three together with TX looped back to RX.        |
| `tb_uart`     | `tb/tb_uart.v`    | Self-checking testbench with a scoreboard and VCD dump.    |

## Design notes

- **Oversampling.** The receiver samples the incoming line 16 times per bit and
  reads each bit at the centre of its window (tick 7 of 16). Sampling mid-bit
  rather than at the edge tolerates small frequency differences between the
  transmitter's and receiver's clocks — the practical reason real UARTs
  oversample instead of sampling once per bit.
- **Start-bit validation.** A candidate start bit is re-checked at its centre;
  if the line is no longer low the receiver treats it as a glitch and returns to
  idle, which rejects narrow noise pulses.
- **Metastability.** The asynchronous `rx` pin passes through a two-flop
  synchroniser before the FSM uses it.
- **Parameterisation.** `CLK_FREQ_HZ`, `BAUD_RATE`, and `OVERSAMPLE` are
  parameters; counter widths are derived with `$clog2`, so the same RTL targets
  any clock/baud combination. The testbench uses a small ratio to keep
  simulation fast while exercising identical logic.

## Running it

You need [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` + `vvp`).
GTKWave is optional, for viewing the waveform.

```bash
# build and run the self-checking testbench
make

# (optional) open the waveform in GTKWave
make wave

# remove generated files
make clean
```

On Ubuntu/Debian: `sudo apt-get install iverilog gtkwave`.

## Repository layout

```
uart-verilog/
├── rtl/            # synthesizable design
│   ├── baud_gen.v
│   ├── uart_tx.v
│   ├── uart_rx.v
│   └── uart_top.v
├── tb/             # testbench
│   └── tb_uart.v
├── sim/            # simulation outputs (VCD ignored by git)
│   └── render_wave.py
├── docs/
│   ├── waveform.png
│   └── waveform.svg
├── Makefile
├── LICENSE
└── README.md
```

## Possible extensions

- Add a parity bit (configurable even/odd) and a parity-error flag.
- Add TX and RX FIFOs for buffered, byte-stream operation.
- Wrap the core in a simple register interface (e.g. APB) for SoC integration.

## License

Released under the MIT License — see [LICENSE](LICENSE).
