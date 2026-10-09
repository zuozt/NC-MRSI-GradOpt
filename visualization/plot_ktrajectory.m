function plot_ktrajectory(result)
%PLOT_KTRAJECTORY Plot target and actual k-space trajectory.
kt = result.ktraj_target;
ka = result.ktraj_actual;
D = size(ka,2);
figure('Name','k-space trajectory');
if D == 1
    plot(result.time_grad, kt(:,1), '--'); hold on;
    plot(result.time_grad, ka(:,1), '-');
    xlabel('Time (s)'); ylabel('k (cycles/m)');
    legend('Target','Actual'); grid on;
elseif D == 2
    plot(kt(:,1), kt(:,2), '--'); hold on;
    plot(ka(:,1), ka(:,2), '-');
    xlabel('kx (cycles/m)'); ylabel('ky (cycles/m)');
    legend('Target','Actual'); axis equal; grid on;
else
    plot3(kt(:,1), kt(:,2), kt(:,3), '--'); hold on;
    plot3(ka(:,1), ka(:,2), ka(:,3), '-');
    xlabel('kx (cycles/m)'); ylabel('ky (cycles/m)'); zlabel('kz (cycles/m)');
    legend('Target','Actual'); axis equal; grid on;
end
end
