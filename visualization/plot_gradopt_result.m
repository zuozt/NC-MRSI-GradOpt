function plot_gradopt_result(result)
%PLOT_GRADOPT_RESULT Plot k-space, gradient, slew, and error figures.
plot_ktrajectory(result);
plot_gradient(result);
plot_slew(result);
plot_error(result);
end
