import re

VCD_PATH = 'my-hls-test/myproject_prj/solution1/sim/verilog/myproject_real.vcd'
OUT_SVG = 'img/xsim_waveform.svg'

with open(VCD_PATH) as f:
    lines = f.readlines()

# Parse $var lines to map single-char id -> (name, width)
id_to_sig = {}
for line in lines:
    m = re.match(r'\$var wire (\d+) (\S) (\S+)', line)
    if m:
        width, vid, name = m.groups()
        id_to_sig[vid] = (name, int(width))

# Parse value-change dump: track time, and per-id value history
events = []  # (time_ps, vid, value)
t = 0
in_dump = False
for line in lines:
    line = line.rstrip('\n')
    if line.startswith('#'):
        t = int(line[1:])
        continue
    if line.startswith('b'):
        # bus value: b<binary> <id>
        val, vid = line[1:].split(' ')
        events.append((t, vid, val))
    elif line and line[0] in '01xXzZ':
        vid = line[1:]
        events.append((t, vid, line[0]))

# Build per-signal transition list: [(time, value), ...]
sig_events = {vid: [] for vid in id_to_sig}
for t, vid, val in events:
    if vid in sig_events:
        sig_events[vid].append((t, val))

# Signals to plot, in display order
ORDER = ['ap_clk', 'ap_rst_n', 'ap_start', 'input_1_TVALID', 'input_1_TREADY',
         'input_1_TDATA', 'layer9_out_TVALID', 'layer9_out_TREADY', 'layer9_out_TDATA',
         'ap_done', 'ap_idle']
name_to_vid = {name: vid for vid, (name, w) in id_to_sig.items()}

end_time = max(t for t, _, _ in events) + 20000

def hex_at(vid, tq):
    # value of signal vid at time tq (last known value at/before tq)
    v = None
    for (tt, val) in sig_events[vid]:
        if tt <= tq:
            v = val
        else:
            break
    return v

# Print a compact text summary for verification/README use
print('=== real captured transitions (subset) ===')
for name in ['ap_start', 'input_1_TVALID', 'input_1_TREADY', 'layer9_out_TVALID', 'layer9_out_TREADY', 'ap_done']:
    vid = name_to_vid[name]
    print(name, sig_events[vid][:10])

print('input_1_TDATA changes:', len(sig_events[name_to_vid['input_1_TDATA']]))
print('layer9_out_TDATA changes:', len(sig_events[name_to_vid['layer9_out_TDATA']]))
for tt, val in sig_events[name_to_vid['layer9_out_TDATA']][:10]:
    print('  layer9_out_TDATA @', tt, 'ps =', hex(int(val, 2)) if val.strip('01') == '' else val)

# ---- render SVG ----
W, H = 1200, 60 + len(ORDER) * 46 + 40
PX0 = 220
PXW = 920
t_start = 0
t_end = end_time

def x_of(tp):
    return PX0 + (tp - t_start) / (t_end - t_start) * PXW

svg = []
svg.append(f'<svg viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg" font-family="IBM Plex Mono, Menlo, monospace">')
svg.append(f'<rect width="{W}" height="{H}" fill="#f7f7f5"/>')
svg.append(f'<text x="20" y="24" font-size="15" font-weight="700" fill="#1a1a1a">Real XSim cosimulation waveform: myproject (hls4ml core), 8 actual test transactions</text>')
svg.append(f'<text x="20" y="40" font-size="10" fill="#555">Parsed from a real VCD captured with log_vcd/get_objects during an actual xsim run (myproject_real.vcd, {len(events)} value changes). Not hand-drawn.</text>')

row_h = 46
y = 60
for name in ORDER:
    vid = name_to_vid[name]
    evs = sig_events[vid]
    width = id_to_sig[vid][1]
    svg.append(f'<text x="10" y="{y+row_h/2+4}" font-size="11" fill="#1a1a1a">{name}</text>')
    svg.append(f'<line x1="{PX0}" y1="{y}" x2="{PX0}" y2="{y+row_h}" stroke="#ddd"/>')
    if width == 1:
        prev_t, prev_v = t_start, '0'
        for (tt, val) in evs:
            if tt < t_start:
                prev_v = val
                continue
            x1, x2 = x_of(prev_t), x_of(tt)
            level = y + row_h - 12 if prev_v == '1' else y + 12
            svg.append(f'<line x1="{x1:.1f}" y1="{level}" x2="{x2:.1f}" y2="{level}" stroke="#2c5f8a" stroke-width="2"/>')
            svg.append(f'<line x1="{x2:.1f}" y1="{y+12}" x2="{x2:.1f}" y2="{y+row_h-12}" stroke="#2c5f8a" stroke-width="2"/>')
            prev_t, prev_v = tt, val
        level = y + row_h - 12 if prev_v == '1' else y + 12
        svg.append(f'<line x1="{x_of(prev_t):.1f}" y1="{level}" x2="{x_of(t_end):.1f}" y2="{level}" stroke="#2c5f8a" stroke-width="2"/>')
    else:
        # bus: draw hex value labels between transitions
        pts = [(tt, val) for tt, val in evs if tt >= t_start] or [(t_start, evs[-1][1] if evs else '0')]
        for i, (tt, val) in enumerate(pts):
            x1 = x_of(tt)
            x2 = x_of(pts[i+1][0]) if i + 1 < len(pts) else x_of(t_end)
            hexv = format(int(val, 2), 'X') if set(val) <= set('01') else val
            if len(hexv) > 10:
                hexv = hexv[:8] + '..'
            svg.append(f'<polygon points="{x1:.1f},{y+8} {x1+6:.1f},{y+row_h/2} {x1:.1f},{y+row_h-8} {x2:.1f},{y+row_h-8} {x2-6:.1f},{y+row_h/2} {x2:.1f},{y+8}" fill="#fdf3e3" stroke="#b5602a" stroke-width="1.5"/>')
            if x2 - x1 > 30:
                svg.append(f'<text x="{(x1+x2)/2:.1f}" y="{y+row_h/2+4}" font-size="9" text-anchor="middle" fill="#1a1a1a">0x{hexv}</text>')
    y += row_h

svg.append('</svg>')

with open(OUT_SVG, 'w') as f:
    f.write('\n'.join(svg))

print('wrote', OUT_SVG, 'end_time_ps=', end_time)
