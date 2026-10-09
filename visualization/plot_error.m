function plot_error(result)
%PLOT_ERROR Plot k-space trajectory error magnitude.
err = result.ktraj_actual - result.ktraj_target;
errMag = sqrt(sum(err.^2,2));
figure('Name','k-space error');
plot(result.time_grad, errMag);
xlabel('Time (s)'); ylabel('|k actual - k target| (cycles/m)'); grid on;
end
