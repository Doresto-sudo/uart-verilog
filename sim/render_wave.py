#!/usr/bin/env python3
"""Render a UART timing-diagram SVG from the simulation VCD.

Picks the first transmitted byte (0x41 = 'A') and draws clk, serial_line,
tx_busy, rx_valid and rx_data over that window so the start bit, 8 LSB-first
data bits and stop bit are clearly visible.
"""
from vcdvcd import VCDVCD

vcd = VCDVCD("sim/uart_tb.vcd")

def find(sig):
    for k in vcd.references_to_ids:
        if k.endswith(sig) or ("." + sig) in k:
            return k
    return None

names = {
    "clk":         "tb_uart.clk",
    "serial_line": "tb_uart.serial_line",
    "tx_busy":     "tb_uart.tx_busy",
    "rx_valid":    "tb_uart.rx_valid",
    "start":       "tb_uart.start",
}
sig_ids = {n: find(s) for n, s in names.items()}

# Window: from just before first start pulse to first rx_valid completion.
# Determine from the 'start' and 'rx_valid' transitions.
def tv(sig):
    return vcd[sig_ids[sig]].tv

start_tv = tv("start")
# first time start goes to 1
t_start = next(t for t, v in start_tv if v == '1')
rxv_tv = tv("rx_valid")
t_rxvalid = next(t for t, v in rxv_tv if v == '1')

t0 = max(0, t_start - 400)
t1 = t_rxvalid + 800

def level_at(sig, t):
    cur = 'x'
    for tt, v in tv(sig):
        if tt <= t:
            cur = v
        else:
            break
    return cur

# Build SVG.
W, H = 1100, 360
left = 110
plot_w = W - left - 30
def x_of(t):
    return left + (t - t0) / (t1 - t0) * plot_w

rows = [
    ("clk",         "clk"),
    ("serial_line", "TX/RX line"),
    ("tx_busy",     "tx_busy"),
    ("rx_valid",    "rx_valid"),
]
row_h = 60
top = 50

svg = []
svg.append(f'<svg viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg" font-family="monospace">')
svg.append(f'<rect width="{W}" height="{H}" fill="#0d1117"/>')
svg.append(f'<text x="{left}" y="28" fill="#e6edf3" font-size="18">UART loopback - transmission of byte 0x41 (&apos;A&apos;), LSB first</text>')

# Sample clk on a grid to draw a square wave.
for idx, (sig, label) in enumerate(rows):
    y_base = top + idx * row_h + 30
    svg.append(f'<text x="10" y="{y_base-4}" fill="#7d8590" font-size="13">{label}</text>')
    hi = y_base - 22
    lo = y_base
    # sample at fine resolution
    N = 1400
    prev = None
    pts = []
    for k in range(N + 1):
        t = t0 + (t1 - t0) * k / N
        v = level_at(sig, t)
        y = hi if v == '1' else lo
        x = x_of(t)
        if prev is not None and prev != y:
            pts.append((x, prev))
        pts.append((x, y))
        prev = y
    path = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    color = "#3fb950" if sig == "serial_line" else "#58a6ff"
    svg.append(f'<path d="{path}" fill="none" stroke="{color}" stroke-width="2"/>')

svg.append('</svg>'.replace('</svg>',''))  # placeholder

# Annotate the bit fields on the serial line row with gridlines + labels.
line_idx = 1
y_base = top + line_idx * row_h + 30
hi = y_base - 22
lo = y_base

# Locate the start of the start bit on the serial line within the window.
serial_tv = tv("serial_line")
t_fall = next((t for t, v in serial_tv if v == '0' and t >= t_start), t_start)

# Bit period in sim time units. From params: 16 clocks/bit, clk period 20ns
# but VCD time is in ps via timescale 1ns/1ps -> 1 step = 1ps; clk toggles
# every 10ns = 10000ps, period 20000ps, 16 clk/bit -> 320000ps/bit.
bit_ps = 320000
labels = ["START", "D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "STOP"]
for bi, lab in enumerate(labels):
    bx0 = x_of(t_fall + bi * bit_ps)
    bx1 = x_of(t_fall + (bi + 1) * bit_ps)
    xc = (bx0 + bx1) / 2
    svg.append(f'<line x1="{bx0:.1f}" y1="{top+10}" x2="{bx0:.1f}" y2="{H-40}" '
               f'stroke="#30363d" stroke-width="1" stroke-dasharray="3 3"/>')
    col = "#f0883e" if lab in ("START", "STOP") else "#7d8590"
    svg.append(f'<text x="{xc:.1f}" y="{top+6}" fill="{col}" font-size="11" '
               f'text-anchor="middle">{lab}</text>')

svg.append(f'<text x="{left}" y="{H-12}" fill="#7d8590" font-size="12">'
           f'Frame 8-N-1: 0x41 = 0100 0001, sent LSB first -&gt; 1 0 0 0 0 0 1 0</text>')

svg.append('</svg>')

with open("docs/waveform.svg", "w") as f:
    f.write("\n".join(svg))

print("Wrote docs/waveform.svg")
print(f"window: t0={t0} t1={t1}  start@{t_start}  rx_valid@{t_rxvalid}")
