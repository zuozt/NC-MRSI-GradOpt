function info = write_periodic_pulseq_module(module, result, filename, repeats, seqOpts)
%WRITE_PERIODIC_PULSEQ_MODULE Write a prepared periodic module to .seq.
%
% The readout is repeated as separate Npp-sample ADC blocks. The compact
% waveform's last-to-first transition is therefore present in the Pulseq
% file exactly as it will be played during the full FID.

if nargin < 4 || isempty(repeats)
    repeats = 1;
end
if nargin < 5 || isempty(seqOpts)
    seqOpts = struct();
end
repeats = max(1,round(repeats));
require_pulseq();
if ~module.isFeasible
    error(['Prepared Pulseq module is infeasible. Check the Pulseq pre/post ' ...
        'gradients, return-to-origin error, hardware limits, and ' ...
        'Optimization Toolbox/quadprog availability.']);
end

gammaBar = module.gammaBar;
sys = mr.opts('MaxGrad',result.opts.Gmax*1e3,'GradUnit','mT/m', ...
    'MaxSlew',result.opts.Smax,'SlewUnit','T/m/s', ...
    'gradRasterTime',module.dtGrad, ...
    'blockDurationRaster',module.dtGrad, ...
    'adcRasterTime',getp(seqOpts,'adcRasterTime',100e-9), ...
    'adcDeadTime',0,'gamma',gammaBar);
GmaxRecovered_Tm = sys.maxGrad/sys.gamma;
assert(abs(GmaxRecovered_Tm-result.opts.Gmax) < 1e-12, ...
    'Pulseq MaxGrad unit conversion failed.');
seq = mr.Sequence(sys);

if isfield(seqOpts,'FOV') && ~isempty(seqOpts.FOV)
    seq.setDefinition('FOV',seqOpts.FOV);
end
seq.setDefinition('Name',getp(seqOpts,'name','NC_MRSI_CRT_periodic_module'));
seq.setDefinition('Npp',module.Npp);
seq.setDefinition('PeriodRepeats',repeats);
seq.setDefinition('GammaBar_HzT',gammaBar);
seq.setDefinition('ADC_centered_kspace',1);
seq.setDefinition('ReturnToKOrigin',1);
if isfield(result,'ringIndex')
    seq.setDefinition('CRTRingIndex',result.ringIndex);
end
if isfield(result,'ringRadius')
    seq.setDefinition('CRTRingRadius_cycles_per_m',result.ringRadius);
end

add_prepost_gradient_block(seq,module.pre,sys,gammaBar);

adc = mr.makeAdc(module.Npp,'Dwell',module.dtADC,'Delay',0,'system',sys);
for pp = 1:repeats
    if isfield(module,'GreadEdge') && ~isempty(module.GreadEdge)
        add_readout_gradient_block(seq,module.GreadEdge,module.dtGrad, ...
            sys,gammaBar,adc);
    else
        % Backward compatibility for modules prepared by an earlier version.
        add_gradient_block(seq,module.Gread,module.Gboundary,module.Gboundary, ...
            sys,gammaBar,adc);
    end
end

add_prepost_gradient_block(seq,module.post,sys,gammaBar);

[timingOK,timingErrors] = seq.checkTiming;
if ~timingOK
    error('Pulseq timing check failed before write:\n%s',join_lines(timingErrors));
end

compatibility = lower(getp(seqOpts,'compatibility','1.4.1'));
switch compatibility
    case {'1.4.1','v1.4.1','141'}
        seq.write_v141(filename);
        fileFormat = '1.4.1';
    case {'current','1.5','1.5.1','v1.5.1'}
        seq.write(filename);
        fileFormat = 'current';
    otherwise
        error('Unknown Pulseq compatibility option: %s',compatibility);
end

info = struct();
info.filename = filename;
info.repeats = repeats;
info.Npp = module.Npp;
info.adcSamples = module.Npp*repeats;
info.readoutDuration = module.Npp*module.dtADC*repeats;
info.preDuration = module.pre.duration;
info.postDuration = module.post.duration;
info.postReturnError_cpm = module.post.returnErrorNorm;
info.totalDuration = info.preDuration+info.readoutDuration+info.postDuration;
info.fileFormat = fileFormat;
info.timingOKBeforeWrite = timingOK;
info.timingErrorsBeforeWrite = timingErrors;
info.sys = sys;
fprintf('Exported Pulseq %s: %s\n',fileFormat,filename);
end

function add_prepost_gradient_block(seq,shape,sys,gammaBar)
if isfield(shape,'Gedge') && isfield(shape,'times')
    times = shape.times(:);
    GedgeHz = gammaBar*shape.Gedge;
    gx = mr.makeExtendedTrapezoid('x','system',sys, ...
        'times',times,'amplitudes',GedgeHz(:,1));
    gy = mr.makeExtendedTrapezoid('y','system',sys, ...
        'times',times,'amplitudes',GedgeHz(:,2));
    gz = mr.makeExtendedTrapezoid('z','system',sys, ...
        'times',times,'amplitudes',GedgeHz(:,3));
    seq.addBlock(gx,gy,gz);
else
    % Backward compatibility for modules prepared by an earlier version.
    add_gradient_block(seq,shape.G,shape.first,shape.last, ...
        sys,gammaBar,[]);
end
end

function add_readout_gradient_block(seq,Gedge,dt,sys,gammaBar,adc)
times = (0:size(Gedge,1)-1).'*dt;
GedgeHz = gammaBar*Gedge;
gx = mr.makeExtendedTrapezoid('x','system',sys, ...
    'times',times,'amplitudes',GedgeHz(:,1));
gy = mr.makeExtendedTrapezoid('y','system',sys, ...
    'times',times,'amplitudes',GedgeHz(:,2));
gz = mr.makeExtendedTrapezoid('z','system',sys, ...
    'times',times,'amplitudes',GedgeHz(:,3));
seq.addBlock(gx,gy,gz,adc);
end

function add_gradient_block(seq,G,first,last,sys,gammaBar,adc)
Ghz = gammaBar*G;
firstHz = gammaBar*first;
lastHz = gammaBar*last;
gx = mr.makeArbitraryGrad('x',Ghz(:,1),'system',sys, ...
    'first',firstHz(1),'last',lastHz(1));
gy = mr.makeArbitraryGrad('y',Ghz(:,2),'system',sys, ...
    'first',firstHz(2),'last',lastHz(2));
gz = mr.makeArbitraryGrad('z',Ghz(:,3),'system',sys, ...
    'first',firstHz(3),'last',lastHz(3));
if isempty(adc)
    seq.addBlock(gx,gy,gz);
else
    seq.addBlock(gx,gy,gz,adc);
end
end

function require_pulseq()
if exist('mr.Sequence','class') ~= 8 && exist('mr.Sequence','file') ~= 2
    error(['Pulseq MATLAB was not found. Run startup_nc_mrsi_gradopt, ' ...
        'or add the Pulseq matlab directory to the MATLAB path.']);
end
end

function s = join_lines(c)
if isempty(c)
    s = '';
elseif ischar(c)
    s = c;
else
    s = strjoin(c,sprintf('\n'));
end
end

function v=getp(s,name,defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v=s.(name);
else
    v=defaultValue;
end
end
