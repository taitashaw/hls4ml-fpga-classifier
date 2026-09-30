import json
import hls4ml

with open('config_final.json') as f:
    config = json.load(f)

hls_model = hls4ml.converters.keras_v2_to_hls(config)
hls_model.compile()

print('=== starting build: synth + cosim + export + vsynth (real Vitis HLS + XSim + Vivado synth) ===')
hls_model.build(csim=False, synth=True, cosim=True, export=True, vsynth=True)
print('=== build() returned ===')

report = hls4ml.report.read_vivado_report('my-hls-test')
print('=== FULL REPORT ===')
print(report)
