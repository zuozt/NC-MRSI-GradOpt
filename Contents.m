% NC-MRSI-GradOpt v0.3.8
%
% A MATLAB research prototype for fixed-duration non-Cartesian MRSI gradient
% waveform optimization under gradient and slew-rate constraints.
%
% Main entry:
%   nc_mrsi_gradopt
%
% GUI:
%   nc_mrsi_gradopt_gui
%   launch_gui
%
% Startup:
%   startup_nc_mrsi_gradopt
%
% See README_CN.md and docs/ for details.
%
% Added trajectory generators:
%   make_concentric_crt_2d - compact-period concentric-ring / CRT trajectory
%   make_concentric_crt_set - complete CRT set with Npp samples per ring
%   make_periodic_crt_2d   - periodic CRT alias for MRSI examples
%   optimize_concentric_crt_set - independently optimize every CRT ring
%   design_post_gradient_to_origin - constrained k-space return to k=0/G=0
%   add_post_gradient_to_periodic_result - save real complete CRT module
%   integrate_gradient - continuous reintegration used by complete modules
%   export_crt_ring_set_csv - combined CSV export for all CRT rings
%   export_crt_ring_set_pulseq - one Pulseq module per CRT ring
%   prepare_periodic_pulseq_module - ADC-centred Pulseq conversion
%   write_periodic_pulseq_module - compact/full-FID .seq writer
%   validate_periodic_pulseq_roundtrip - write/read physics validation
%   validate_crt_ring_set_pulseq - six-ring automated validation/report
%   run_crt_pulseq_roundtrip - one-command export and validation
