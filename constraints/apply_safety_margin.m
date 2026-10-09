function sys2 = apply_safety_margin(sys, margin)
%APPLY_SAFETY_MARGIN Return hardware limits after applying safety margin.
if nargin < 2 || isempty(margin)
    margin = 0.95;
end
sys2 = sys;
sys2.Gmax = sys.Gmax * margin;
sys2.Smax = sys.Smax * margin;
end
