import numpy as np

x = np.load('x_test.npy')[:8]
y = np.load('y_keras.npy')[:8]

with open('my-hls-test/tb_data/tb_input_features.dat', 'w') as f:
    for row in x:
        f.write(' '.join(f'{v:.6f}' for v in row) + '\n')

with open('my-hls-test/tb_data/tb_output_predictions.dat', 'w') as f:
    for row in y:
        f.write(' '.join(f'{v:.6f}' for v in row) + '\n')

print('wrote', len(x), 'real, varied samples to tb_data/')
print('sample 0 input :', x[0])
print('sample 0 y_keras:', y[0])
print('sample 1 input :', x[1])
print('sample 1 y_keras:', y[1])
