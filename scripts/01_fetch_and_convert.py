import hls4ml
import numpy as np
import json

# Real example model, fetched live from fastmachinelearning/example-models
config = hls4ml.utils.fetch_example_model('KERAS_3layer.json', backend='Vitis')

print('=== fetched config (as-downloaded) ===')
print(json.dumps(config, indent=2))

# Override target for this session's real hardware: ZCU104 (Zynq UltraScale+ ZU7EV)
# NOTE: the dict key consumed by keras_v2_to_hls/writer is "Part", not "XilinxPart"
# (XilinxPart is the config_from_keras_model()-style key) -- caught by inspecting
# the as-fetched dict above before assuming the key name.
config['Part'] = 'xczu7ev-ffvc1156-2-e'
config['ClockPeriod'] = 10  # ns -> 100 MHz
config['IOType'] = 'io_stream'

print('=== config after ZCU104 override ===')
print(json.dumps(config, indent=2))

with open('config_final.json', 'w') as f:
    json.dump(config, f, indent=2)

hls_model = hls4ml.converters.keras_v2_to_hls(config)
hls_model.compile()
print('=== compiled OK, HLS project written to:', config['OutputDir'], '===')

# Real golden-reference predictions: load the actual Keras model + real weights
# that fetch_example_model just downloaded, generate representative input, and
# run both the float Keras model and the compiled HLS C-simulation model on it.
import tensorflow as tf
# KERAS_3layer.json is a legacy Keras-2/TF1 functional-API save (class_name
# "Model", keras_version 2.0.0). tf.keras.models.model_from_json() under the
# installed Keras 3 fails on that legacy format ("Could not locate class
# 'Model'") -- confirmed by actually running it, not assumed. The real
# architecture and layer names are already verified from the same downloaded
# JSON (16 -> Dense(64,relu,'fc1_relu') -> Dense(32,relu,'fc2_relu') ->
# Dense(32,relu,'fc3_relu') -> Dense(5,softmax,'output_softmax')), so rebuild
# that exact graph natively in Keras 3 and load the real downloaded H5 weights
# into it by layer name. Same real architecture, same real trained weights,
# just constructed through a loader that understands them.
inp = tf.keras.Input(shape=(16,), name='input_1')
x = tf.keras.layers.Dense(64, activation='relu', name='fc1_relu')(inp)
x = tf.keras.layers.Dense(32, activation='relu', name='fc2_relu')(x)
x = tf.keras.layers.Dense(32, activation='relu', name='fc3_relu')(x)
out = tf.keras.layers.Dense(5, activation='softmax', name='output_softmax')(x)
keras_model = tf.keras.Model(inp, out)
keras_model.load_weights('KERAS_3layer_weights.h5')
keras_model.summary()

rng = np.random.RandomState(42)
n_in = keras_model.input_shape[1]
x_test = rng.uniform(-1, 1, size=(1000, n_in)).astype('float32')

y_keras = keras_model.predict(x_test, verbose=0)
y_hls = hls_model.predict(x_test)

np.save('x_test.npy', x_test)
np.save('y_keras.npy', y_keras)
np.save('y_hls_csim.npy', y_hls)

err = np.abs(y_keras - y_hls)
print('=== C-simulation vs Keras float reference (n=1000) ===')
print('input shape:', x_test.shape, 'output shape:', y_keras.shape)
print('max abs error :', err.max())
print('mean abs error:', err.mean())
print('keras argmax == hls argmax agreement:',
      (y_keras.argmax(axis=1) == y_hls.argmax(axis=1)).mean())
