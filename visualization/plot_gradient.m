function plot_gradient(result)
%PLOT_GRADIENT Plot gradient waveform.
figure('Name','Gradient waveform');
plot(result.time_grad, result.G * 1e3);
xlabel('Time (s)'); ylabel('Gradient (mT/m)');
legend(axis_labels(size(result.G,2), 'G'), 'Location', 'best'); grid on;
end

function labels = axis_labels(D, prefix)
base = {'x','y','z'};
labels = cell(1,D);
for i = 1:D
    labels{i} = [prefix base{i}];
end
end
