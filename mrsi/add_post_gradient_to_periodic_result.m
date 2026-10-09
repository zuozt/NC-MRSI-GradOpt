function result = add_post_gradient_to_periodic_result(result, Npost)
%ADD_POST_GRADIENT_TO_PERIODIC_RESULT Add a real k-space return after ADC.
%
% The final gradient sample of a periodic ring closes the last ADC position
% back to the first ring position.  The post-gradient starts from that final
% readout gradient, cancels the remaining k-space moment, and ends at G=0.

if nargin < 2
    Npost = [];
end
if ~isfield(result,'G') || isempty(result.G)
    error('result.G is required.');
end
if ~isfield(result,'ktraj_actual') || isempty(result.ktraj_actual)
    error('result.ktraj_actual is required.');
end
if ~isfield(result,'opts') || isempty(result.opts)
    error('result.opts is required.');
end

opts = result.opts;
kAfterReadout = result.ktraj_actual(end,:) + ...
    opts.gammaBar * opts.dtGrad * result.G(end,:);
GStart = result.G(end,:);
post = design_post_gradient_to_origin(kAfterReadout,GStart,opts,Npost);
post.readoutClosurePoint = kAfterReadout;
post.readoutClosureMismatch = kAfterReadout-result.ktraj_actual(1,:);
post.readoutClosureMismatchNorm = norm(post.readoutClosureMismatch);
result.post = post;
result = build_complete_sequence(result);
end

function result = build_complete_sequence(result)
Nread = size(result.G,1);
dt = result.opts.dtGrad;

Gparts = {};
tparts = {};
adcParts = {};
segmentParts = {};
if isfield(result,'pre') && isstruct(result.pre) && ...
        isfield(result.pre,'G') && ~isempty(result.pre.G)
    Npre = size(result.pre.G,1);
    Gparts{end+1} = result.pre.G; %#ok<AGROW>
    tparts{end+1} = ((-Npre):-1).'*dt; %#ok<AGROW>
    adcParts{end+1} = zeros(Npre,1); %#ok<AGROW>
    segmentParts{end+1} = zeros(Npre,1); %#ok<AGROW>
    kInitial = zeros(1,size(result.G,2));
else
    Npre = 0;
    % Without a pre-gradient, retain the periodic readout's physical
    % starting position. Complete CRT modules normally use the branch above.
    kInitial = result.ktraj_actual(1,:);
end

Gparts{end+1} = result.G;
tparts{end+1} = (0:Nread-1).'*dt;
adcParts{end+1} = ones(Nread,1);
segmentParts{end+1} = ones(Nread,1);

Npost = size(result.post.G,1);
Gparts{end+1} = result.post.G;
tparts{end+1} = (Nread:Nread+Npost-1).'*dt;
adcParts{end+1} = zeros(Npost,1);
segmentParts{end+1} = 2*ones(Npost,1);

Gmodule = vertcat(Gparts{:});
kmodule = integrate_gradient(Gmodule,result.opts,kInitial);
result.sequence = struct();
result.sequence.kind = 'real complete CRT module: pre + ADC ring + post';
result.sequence.integrationConvention = ...
    'continuous interval integration from sequence.G on one time axis';
result.sequence.G = Gmodule;
result.sequence.S = diff(Gmodule,1,1)./dt;
result.sequence.ktraj_actual = kmodule;
result.sequence.time_grad = vertcat(tparts{:});
result.sequence.adcMask = vertcat(adcParts{:});
result.sequence.segmentCode = vertcat(segmentParts{:});
result.sequence.segmentLabels = {'pre-gradient','ADC ring','post-gradient'};
result.sequence.adcStartIndex = Npre+1;
result.sequence.adcEndIndex = Npre+Nread;
result.sequence.postStartIndex = Npre+Nread+1;
result.sequence.readoutClosureIndex = result.sequence.postStartIndex;
result.sequence.readoutClosurePoint = ...
    kmodule(result.sequence.readoutClosureIndex,:);
result.sequence.ktraj_pre = kmodule(1:Npre,:);
result.sequence.ktraj_adc = ...
    kmodule(result.sequence.adcStartIndex:result.sequence.adcEndIndex,:);
result.sequence.ktraj_post = ...
    kmodule(result.sequence.postStartIndex:end,:);
result.sequence.preDuration = Npre*dt;
result.sequence.readoutDuration = Nread*dt;
result.sequence.postDuration = Npost*dt;
result.sequence.totalDuration = size(Gmodule,1)*dt;
result.sequence.maxGAxis = max(abs(Gmodule),[],1);
result.sequence.maxSAxis = max(abs(result.sequence.S),[],1);
if isfield(result,'report') && isfield(result.report,'maxGAxis')
    result.sequence.maxGAxis = max([result.sequence.maxGAxis; ...
        result.report.maxGAxis],[],1);
end
if isfield(result,'report') && isfield(result.report,'maxSAxis')
    result.sequence.maxSAxis = max([result.sequence.maxSAxis; ...
        result.report.maxSAxis],[],1);
end
result.sequence.returnError = kmodule(end,:);
result.sequence.returnErrorNorm = norm(result.sequence.returnError);
result.sequence.terminalReturnError = kInitial + ...
    result.opts.gammaBar*dt*sum(Gmodule,1);
result.sequence.terminalReturnErrorNorm = ...
    norm(result.sequence.terminalReturnError);
result.sequence.postSolverReturnError = result.post.returnError;
result.sequence.postSolverReturnErrorNorm = result.post.returnErrorNorm;
prePass = true;
if isfield(result,'pre') && isfield(result.pre,'isFeasible')
    prePass = logical(result.pre.isFeasible);
end
readoutPass = true;
if isfield(result,'report') && isfield(result.report,'isFeasible')
    readoutPass = logical(result.report.isFeasible);
end
result.sequence.isFeasible = prePass && readoutPass && result.post.isFeasible && ...
    all(result.sequence.maxGAxis <= result.opts.Guse*(1+1e-8)) && ...
    all(result.sequence.maxSAxis <= result.opts.Suse*(1+1e-8)) && ...
    result.sequence.returnErrorNorm < 1e-6 && ...
    result.sequence.terminalReturnErrorNorm < 1e-6;
end
