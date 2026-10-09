function plot_slew(result)
%PLOT_SLEW Plot slew-rate waveform.
t = result.time_grad(1:end-1);
figure('Name','Slew-rate waveform');
plot(t, result.S);
xlabel('Time (s)'); ylabel('Slew rate (T/m/s)');
legend(axis_labels(size(result.S,2), 'S'), 'Location', 'best'); grid on;
end

function labels = axis_labels(D, prefix)
base = {'x','y','z'};
labels = cell(1,D);
for i = 1:D
    labels{i} = [prefix base{i}];
end
end
