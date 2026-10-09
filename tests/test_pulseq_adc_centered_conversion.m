%% Test Pulseq ADC-centred conversion without writing a .seq file
N=128;
radius=25;
theta=(0:N-1).'*2*pi/N;
k=[radius*cos(theta) radius*sin(theta)];
gammaBar=42.5774789e6;
dt=5e-6;
Glegacy=[diff(k,1,1);k(1,:)-k(end,:)]/(gammaBar*dt);

result=struct();
result.G=Glegacy;
result.ktraj_actual=k;
result.ktraj_target=k;
result.opts=struct('gammaBar',gammaBar,'dtGrad',dt,'dtADC',dt, ...
    'nADC',N,'Guse',20e-3,'Suse',180,'Gmax',20e-3,'Smax',180);
module=prepare_periodic_pulseq_module(result);

assert(module.Npp==N);
assert(module.conversion.maxKStepResidual_cpm<1e-8);
assert(module.pre.momentErrorNorm<1e-6);
assert(module.post.returnErrorNorm<1e-6);
assert(module.returnPass);
if exist('quadprog','file')==2
    assert(module.pre.isFeasible);
    assert(module.post.isFeasible);
    assert(module.hardwarePass);
end

dkPulseq=0.5*gammaBar*dt*(module.Gread+module.Gread([2:end 1],:));
dkTarget=[diff(k,1,1);k(1,:)-k(end,:)];
assert(max(abs(dkPulseq(:)-dkTarget(:)))<1e-8);
disp('test_pulseq_adc_centered_conversion passed.');
