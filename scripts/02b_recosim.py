import json
import hls4ml

with open('config_final.json') as f:
    config = json.load(f)

hls_model = hls4ml.converters.keras_v2_to_hls(config)
hls_model.compile()

print('=== re-running cosim only, against real varied tb_data written from actual x_test/y_keras ===')
hls_model.build(csim=False, synth=False, cosim=True, export=False, vsynth=False)
print('=== recosim build() returned ===')
