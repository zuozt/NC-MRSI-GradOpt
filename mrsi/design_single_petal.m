function result = design_single_petal(ktraj_petal, sys, acq, opt)
%DESIGN_SINGLE_PETAL Convenience wrapper for a single MRSI petal.
if ~isfield(opt, 'mode') || isempty(opt.mode)
    opt.mode = 'symmetric_fixed';
end
if ~isfield(opt, 'symmetry') || isempty(opt.symmetry)
    opt.symmetry = 'antisymmetric_k';
end
result = nc_mrsi_gradopt(ktraj_petal, sys, acq, opt);
end
