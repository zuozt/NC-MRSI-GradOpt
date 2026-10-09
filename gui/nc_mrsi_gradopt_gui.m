function nc_mrsi_gradopt_gui()
%NC_MRSI_GRADOPT_GUI Interactive GUI for NC-MRSI-GradOpt.
%
% v0.3.8 continuous-reintegration update:
%   sequence.ktraj_actual and full.ktraj_with_module are generated only by
%   continuous reintegration of their complete gradient arrays. GUI paths,
%   closure points, and return summaries use those reintegrated trajectories.
%
% v0.3.7 CRT complete-module update:
%   Every CRT ring has a real hardware-constrained post-gradient that cancels
%   the ring-start moment and ends at k=0, G=0. The all-rings panel plots
%   k=0 -> real pre-gradient -> ADC ring -> real post-gradient -> k=0.
%
% v0.3.5 CRT/Pulseq update:
%   Adds multi_ring_set: every CRT ring is an independently optimized compact
%   period containing Npp samples and its own optional pre-gradient.
%
% v0.3.2 CRT GUI update:
%   Adds an optional zero-start pre-gradient before the CRT ring. The pre-gradient
%   is outside the ADC window and moves k-space from the origin to the selected
%   ring start while ending at the first readout gradient.
%
% v0.3.1 CRT GUI update:
%   Makes single_ring the default CRT mode and treats multi_ring_period as a
%   diagnostic stress-test because packing several rings into one 480 us period
%   is usually infeasible for MRSI.
%
% v0.2.6 PETALUTE target correction:
%   Periodic rosette target uses the reference PETALUTE formula:
%   Kxy = Kmax*cos(phi)*sin(omega1*t)*exp(i*(omega2*t+beta));
%   Kz  = Kmax*sin(phi)*sin(omega1*t), with omega1=omega2=pi*SBW.
%   Npp is the number of points in ONE spatial trajectory period, and Nspec
%   is the number of repeated periods/FID spectral points.

rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

state = struct();
state.importedKtraj = [];
state.lastTarget = [];
state.lastPreview = [];
state.lastResult = [];
state.lastFull = [];
state.lastConfig = [];
state.crt = defaultCrtParams();

fig = figure('Name','NC-MRSI-GradOpt GUI v0.3.8 continuous full-module trajectory', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','figure', ...
    'Units','normalized', ...
    'Position',[0.03 0.04 0.94 0.90], ...
    'Color',[0.94 0.94 0.94]);

left = uipanel('Parent',fig, 'Title','Parameters', ...
    'Units','normalized', 'Position',[0.01 0.01 0.31 0.98]);
right = uipanel('Parent',fig, 'Title','Periodic MRSI trajectory / gradient / slew', ...
    'Units','normalized', 'Position',[0.33 0.01 0.66 0.98]);

handles = struct();
handles.state = state;
handles.fig = fig;
handles.left = left;
handles.right = right;

% Axes layout: main GUI now explicitly separates k-components and gradient components.
handles.axKcomp = axes('Parent',right, 'Units','normalized', 'Position',[0.06 0.72 0.43 0.22]);
handles.axKspace = axes('Parent',right, 'Units','normalized', 'Position',[0.56 0.72 0.38 0.22]);
handles.axG = axes('Parent',right, 'Units','normalized', 'Position',[0.06 0.45 0.88 0.20]);
handles.axS = axes('Parent',right, 'Units','normalized', 'Position',[0.06 0.21 0.88 0.18]);
handles.axErr = axes('Parent',right, 'Units','normalized', 'Position',[0.06 0.045 0.43 0.12]);

handles.reportBox = uicontrol('Parent',right, 'Style','listbox', ...
    'Units','normalized', 'Position',[0.55 0.045 0.39 0.13], ...
    'FontName','Consolas', 'FontSize',8, 'String',{'Report will appear here.'});

% Right-side fixed action buttons stay visible even if left controls are crowded.
handles.generateBtn2 = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.06 0.005 0.14 0.030], 'String','Generate target', 'Callback',@onGenerateTarget);
handles.optimizeBtn2 = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.21 0.005 0.14 0.030], 'String','Run optimization', 'Callback',@onRunOptimization);
handles.kErrorBtn = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.36 0.005 0.12 0.030], 'String','K error popup', 'Callback',@onKErrorPopup);
handles.exportCsvBtn2 = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.49 0.005 0.10 0.030], 'String','Export CSV', 'Callback',@onExportCsv);
handles.saveMatBtn2 = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.60 0.005 0.10 0.030], 'String','Save MAT', 'Callback',@onSaveMat);
handles.pulseqBtn2 = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.71 0.005 0.12 0.030], 'String','Pulseq verify', 'Callback',@onPulseqVerify);
handles.resetBtn2 = uicontrol('Parent',right, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[0.84 0.005 0.10 0.030], 'String','Reset view', 'Callback',@onResetView);

% Left controls
row = 0.955;
dy = 0.030;
labelH = 0.022;
editH = 0.026;

addHeader('Trajectory');
handles.periodicMrsi = addCheck('Periodic MRSI mode', true);
handles.trajType = addPopup('Trajectory', {'Rosette 2D','Rosette 3D','Spiral 2D','Concentric CRT 2D','Radial 2D','Cones 3D','Workspace/CSV ktraj'}, 2);
handles.Ntarget = addEdit('Target samples (periodic=Npp)', '128');
handles.Kmax = addEdit('Kmax (cycles/m)', '25');
handles.nRadial = addEdit('Radial oscillations/period', '1');
handles.nAngular = addEdit('Angular rotations/period', '1');
handles.phiDeg = addEdit('Out-of-plane phi (deg)', '20');
handles.betaDeg = addEdit('Initial beta (deg)', '0');
handles.workspaceVar = addEdit('Workspace ktraj variable', 'ktraj');
handles.loadCsvBtn = addButton('Load ktraj CSV...', @onLoadCsv);
handles.crtSettingsBtn = addButton('CRT settings...', @onCrtSettings);

addHeader('Hardware');
handles.Gmax = addEdit('Gmax (mT/m)', '20');
handles.Smax = addEdit('Smax (T/m/s)', '180');
handles.dtGradUs = addEdit('Gradient raster (us)', '5');
handles.nucleus = addPopup('Nucleus', {'31P','1H','13C','23Na','Custom'}, 2);
handles.gammaBarMHz = addEdit('gamma/2pi (MHz/T)', '42.5774789');

addHeader('Periodic MRSI timing');
handles.Npp = addEdit('Npp = points/period', '128');
handles.Nspec = addEdit('Nspec = periods/FID', '512');
handles.adcDwellUs = addEdit('ADC dwell inside period (us)', '5');
handles.nADCtotalText = addTextValue('ADC samples total', '65536');
handles.spectralBWText = addTextValue('Derived spectral BW (Hz)', '1562.5');
handles.readoutTimeText = addTextValue('Readout time (ms)', '327.680');
handles.adcDelayMs = addEdit('ADC delay (ms)', '0');

addHeader('Optimization');
handles.mode = addPopup('Mode', {'periodic_fixed','fixed_duration','symmetric_fixed','direct'}, 1);
handles.symmetry = addPopup('Symmetry', {'none','antisymmetric_k','even_k'}, 1);
handles.safety = addEdit('Safety margin', '0.95');
handles.maxControl = addEdit('Max control points', '256');
handles.lambdaSlew = addEdit('lambda slew', '0');
handles.lambdaSmooth = addEdit('lambda smooth', '0');

handles.generateBtn = addButton('Generate target only', @onGenerateTarget);
handles.optimizeBtn = addButton('Run optimization', @onRunOptimization);
handles.exportCsvBtn = addButton('Export CSV', @onExportCsv);
handles.saveMatBtn = addButton('Save result MAT', @onSaveMat);
handles.resetBtn = addButton('Reset view', @onResetView);

handles.statusText = uicontrol('Parent',left, 'Style','text', ...
    'Units','normalized', 'Position',[0.04 0.004 0.92 0.035], ...
    'HorizontalAlignment','left', 'FontSize',8, ...
    'String','Ready. Npp defines one complete spatial period.');

guidata(fig, handles);
updateNucleusGamma();
set(handles.nucleus, 'Callback', @(~,~) updateNucleusGamma());
set(handles.trajType, 'Callback', @onTrajectoryChanged);
setPeriodicCallbacks();
updateDerivedTiming();
onGenerateTarget();

    function addHeader(txt)
        row = row - 0.006;
        uicontrol('Parent',left, 'Style','text', 'Units','normalized', ...
            'Position',[0.04 row 0.92 labelH], 'String',txt, ...
            'HorizontalAlignment','left', 'FontWeight','bold', 'ForegroundColor',[0.10 0.10 0.10]);
        row = row - dy;
    end

    function h = addEdit(lbl, val)
        uicontrol('Parent',left, 'Style','text', 'Units','normalized', ...
            'Position',[0.04 row 0.54 labelH], 'String',lbl, 'HorizontalAlignment','left');
        h = uicontrol('Parent',left, 'Style','edit', 'Units','normalized', ...
            'Position',[0.59 row 0.37 editH], 'String',val, 'BackgroundColor','white');
        row = row - dy;
    end

    function h = addTextValue(lbl, val)
        uicontrol('Parent',left, 'Style','text', 'Units','normalized', ...
            'Position',[0.04 row 0.54 labelH], 'String',lbl, 'HorizontalAlignment','left');
        h = uicontrol('Parent',left, 'Style','text', 'Units','normalized', ...
            'Position',[0.59 row 0.37 editH], 'String',val, 'HorizontalAlignment','left', ...
            'BackgroundColor',[0.90 0.90 0.90], 'FontName','Consolas');
        row = row - dy;
    end

    function h = addCheck(lbl, val)
        h = uicontrol('Parent',left, 'Style','checkbox', 'Units','normalized', ...
            'Position',[0.04 row 0.92 editH], 'String',lbl, 'Value',double(val), ...
            'BackgroundColor',get(left,'BackgroundColor'));
        row = row - dy;
    end

    function h = addPopup(lbl, values, defaultIdx)
        uicontrol('Parent',left, 'Style','text', 'Units','normalized', ...
            'Position',[0.04 row 0.54 labelH], 'String',lbl, 'HorizontalAlignment','left');
        h = uicontrol('Parent',left, 'Style','popupmenu', 'Units','normalized', ...
            'Position',[0.59 row 0.37 editH], 'String',values, 'Value',defaultIdx, 'BackgroundColor','white');
        row = row - dy;
    end

    function h = addButton(txt, callbackFun)
        h = uicontrol('Parent',left, 'Style','pushbutton', 'Units','normalized', ...
            'Position',[0.04 row 0.92 0.028], 'String',txt, 'Callback',callbackFun);
        row = row - 0.034;
    end

    function setPeriodicCallbacks()
        handles = guidata(fig);
        set(handles.Ntarget, 'Callback', @onTargetSamplesChanged);
        set(handles.Npp, 'Callback', @onNppChanged);
        cb = @(~,~) updateDerivedTiming();
        set(handles.Nspec, 'Callback', cb);
        set(handles.adcDwellUs, 'Callback', cb);
        set(handles.periodicMrsi, 'Callback', cb);
    end

    function onTargetSamplesChanged(~,~)
        % In periodic MRSI, target samples per period and Npp are the same
        % physical quantity. Keep them synchronized so changing either field
        % actually changes the compact-period target and optimizer length.
        handles = guidata(fig);
        if get(handles.periodicMrsi,'Value') ~= 0
            val = round(str2double(get(handles.Ntarget,'String')));
            if isfinite(val) && val > 0
                set(handles.Npp,'String',num2str(val));
            end
        end
        updateDerivedTiming();
    end

    function onNppChanged(~,~)
        updateDerivedTiming();
    end

    function updateDerivedTiming()
        handles = guidata(fig);
        try
            Npp = round(str2double(get(handles.Npp,'String')));
            Nspec = round(str2double(get(handles.Nspec,'String')));
            dwellUs = str2double(get(handles.adcDwellUs,'String'));
            if ~isfinite(Npp) || Npp < 1
                Npp = 128;
            end
            if ~isfinite(Nspec) || Nspec < 1
                Nspec = 512;
            end
            if ~isfinite(dwellUs) || dwellUs <= 0
                dwellUs = 5;
            end
            nADCtotal = Npp * Nspec;
            Tperiod = Npp * dwellUs * 1e-6;
            sbw = 1 / Tperiod;
            readoutMs = nADCtotal * dwellUs * 1e-3;
            set(handles.Npp,'String',num2str(Npp));
            if get(handles.periodicMrsi,'Value') ~= 0
                set(handles.Ntarget,'String',num2str(Npp));
            end
            set(handles.Nspec,'String',num2str(Nspec));
            set(handles.nADCtotalText,'String',num2str(nADCtotal));
            set(handles.spectralBWText,'String',sprintf('%.6g', sbw));
            set(handles.readoutTimeText,'String',sprintf('%.6g', readoutMs));
        catch
            % Avoid recursive GUI errors while typing.
        end
    end

    function onLoadCsv(~,~)
        handles = guidata(fig);
        [fileName, pathName] = uigetfile({'*.csv;*.txt','Trajectory files (*.csv, *.txt)'; '*.*','All files'}, 'Select k-space trajectory file');
        if isequal(fileName,0)
            return;
        end
        filePath = fullfile(pathName, fileName);
        try
            data = readmatrix_compat(filePath);
            if size(data,2) > 3
                data = data(:,1:3);
            end
            if size(data,2) < 1 || size(data,2) > 3
                error('CSV/TXT file must contain 1 to 3 numeric columns.');
            end
            handles.state.importedKtraj = data;
            handles.state.lastTarget = data;
            guidata(fig, handles);
            set(handles.trajType,'Value',numel(get(handles.trajType,'String')));
            setStatus(sprintf('Loaded ktraj CSV: %s', fileName));
            onGenerateTarget();
        catch ME
            showError(ME);
        end
    end

    function onTrajectoryChanged(~,~)
        handles = guidata(fig);
        cfgName = getPopupValue(handles.trajType);
        if strcmp(cfgName, 'Concentric CRT 2D')
            setStatus('Concentric CRT selected. multi_ring_set gives every ring its own Npp-sample compact period. multi_ring_period remains a stress test.');
        else
            setStatus(sprintf('%s selected.', cfgName));
        end
    end

    function onCrtSettings(~,~)
        handles = guidata(fig);
        if ~isfield(handles.state,'crt') || isempty(handles.state.crt)
            handles.state.crt = defaultCrtParams();
        end
        crt = ensureCrtDefaults(handles.state.crt);
        handles.state.crt = crt;
        guidata(fig, handles);

        d = dialog('Name','Concentric CRT settings', ...
            'Units','normalized', 'Position',[0.30 0.08 0.40 0.82], ...
            'WindowStyle','modal');
        panel = uipanel('Parent',d, 'Title','CRT-specific parameters', ...
            'Units','normalized', 'Position',[0.03 0.10 0.94 0.87]);
        y = 0.91;
        dy2 = 0.055;
        labelW = 0.47;
        ctrlW = 0.42;
        xLabel = 0.05;
        xCtrl = 0.53;

        uicontrol('Parent',panel,'Style','text','Units','normalized', ...
            'Position',[0.05 y 0.90 0.045], ...
            'HorizontalAlignment','left', ...
            'String','For CRT MRSI, multi_ring_set builds separate complete modules: every ring has Npp ADC samples plus its own real pre-gradient and return-to-origin post-gradient.');
        y = y - 0.085;

        crtModes = {'multi_ring_set','single_ring','multi_ring_period'};
        modePopup = addDlgPopup('CRT mode', crtModes, find(strcmp(crtModes, crt.mode),1));
        useFovCheck = addDlgCheck('Derive Kmax/nRings from FOV and resolution', crt.useFovResolution);
        fovEdit = addDlgEdit('FOV (mm)', crt.fov_mm);
        resEdit = addDlgEdit('Nominal resolution (mm)', crt.resolution_mm);
        nRingsEdit = addDlgEdit('Number of rings', crt.nRings);
        ringIndexEdit = addDlgEdit('Ring index for single_ring', crt.ringIndex);
        turnsEdit = addDlgEdit('Turns per ring', crt.nTurnsPerRing);
        rMinEdit = addDlgEdit('Inner radius rMin (cycles/m, 0=auto)', crt.rMin);
        transEdit = addDlgEdit('Transition fraction', crt.transitionFraction);
        altCheck = addDlgCheck('Alternate direction between rings', crt.alternateDirection);
        preCheck = addDlgCheck('Add zero-start pre-gradient before ring', crt.usePreGradient);
        preSamplesEdit = addDlgEdit('Pre-gradient samples (0=auto)', crt.preGradientSamples);
        postCheck = addDlgCheck('Add return-to-origin post-gradient', crt.usePostGradient);
        postSamplesEdit = addDlgEdit('Post-gradient samples (0=auto)', crt.postGradientSamples);
        hardC0C1Check = addDlgCheck('Hard C0/C1 equality at ring boundary', crt.forceHardC0C1);

        uicontrol('Parent',d,'Style','pushbutton','Units','normalized', ...
            'Position',[0.18 0.025 0.28 0.055], 'String','Apply', 'Callback',@applyCrtDialog);
        uicontrol('Parent',d,'Style','pushbutton','Units','normalized', ...
            'Position',[0.54 0.025 0.28 0.055], 'String','Cancel', 'Callback',@(src,evt) delete(d));

        function h = addDlgEdit(lbl, val)
            uicontrol('Parent',panel,'Style','text','Units','normalized', ...
                'Position',[xLabel y labelW 0.045], 'String',lbl, 'HorizontalAlignment','left');
            h = uicontrol('Parent',panel,'Style','edit','Units','normalized', ...
                'Position',[xCtrl y ctrlW 0.050], 'String',num2str(val), 'BackgroundColor','white');
            y = y - dy2;
        end

        function h = addDlgPopup(lbl, values, defaultIdx)
            if isempty(defaultIdx), defaultIdx = 1; end
            uicontrol('Parent',panel,'Style','text','Units','normalized', ...
                'Position',[xLabel y labelW 0.045], 'String',lbl, 'HorizontalAlignment','left');
            h = uicontrol('Parent',panel,'Style','popupmenu','Units','normalized', ...
                'Position',[xCtrl y ctrlW 0.050], 'String',values, 'Value',defaultIdx, 'BackgroundColor','white');
            y = y - dy2;
        end

        function h = addDlgCheck(lbl, val)
            h = uicontrol('Parent',panel,'Style','checkbox','Units','normalized', ...
                'Position',[xLabel y 0.90 0.050], 'String',lbl, 'Value',double(val), ...
                'BackgroundColor',get(panel,'BackgroundColor'));
            y = y - dy2;
        end

        function applyCrtDialog(~,~)
            try
                newCrt = struct();
                modes = get(modePopup,'String');
                newCrt.mode = modes{get(modePopup,'Value')};
                newCrt.useFovResolution = get(useFovCheck,'Value') ~= 0;
                newCrt.fov_mm = readDialogPositive(fovEdit, 'FOV');
                newCrt.resolution_mm = readDialogPositive(resEdit, 'Nominal resolution');
                newCrt.nRings = max(1, round(readDialogPositive(nRingsEdit, 'Number of rings')));
                newCrt.ringIndex = max(1, round(readDialogPositive(ringIndexEdit, 'Ring index')));
                newCrt.nTurnsPerRing = readDialogPositive(turnsEdit, 'Turns per ring');
                newCrt.rMin = readDialogNonnegative(rMinEdit, 'rMin');
                newCrt.transitionFraction = readDialogNonnegative(transEdit, 'Transition fraction');
                if newCrt.transitionFraction >= 0.50
                    error('Transition fraction should be < 0.5. Typical values are 0.05-0.25.');
                end
                newCrt.alternateDirection = get(altCheck,'Value') ~= 0;
                newCrt.usePreGradient = get(preCheck,'Value') ~= 0;
                newCrt.preGradientSamples = round(readDialogNonnegative(preSamplesEdit, 'Pre-gradient samples'));
                newCrt.usePostGradient = get(postCheck,'Value') ~= 0;
                newCrt.postGradientSamples = round(readDialogNonnegative(postSamplesEdit, 'Post-gradient samples'));
                newCrt.forceHardC0C1 = get(hardC0C1Check,'Value') ~= 0;

                if strcmp(newCrt.mode,'multi_ring_period')
                    uiwait(warndlg(['multi_ring_period packs several rings into one compact spectral period. ', ...
                        'This is usually infeasible at short period durations. For a complete CRT acquisition, use multi_ring_set.'], ...
                        'CRT feasibility warning'));
                end

                handles = guidata(fig);
                if newCrt.useFovResolution
                    fov_m = newCrt.fov_mm * 1e-3;
                    res_m = newCrt.resolution_mm * 1e-3;
                    kmaxAuto = 1/(2*res_m);
                    dk = 1/fov_m;
                    newCrt.nRings = max(1, round(kmaxAuto/dk));
                    newCrt.rMin = dk;
                    newCrt.ringIndex = min(max(1,newCrt.ringIndex), newCrt.nRings);
                    set(handles.Kmax,'String',sprintf('%.6g',kmaxAuto));
                    set(handles.nRadial,'String',num2str(newCrt.nRings));
                    set(handles.nAngular,'String',sprintf('%.6g',newCrt.nTurnsPerRing));
                    set(handles.trajType,'Value',find(strcmp(get(handles.trajType,'String'),'Concentric CRT 2D'),1));
                end
                handles.state.crt = newCrt;
                guidata(fig, handles);
                setStatus(crtSummaryString(newCrt));
                delete(d);
                if strcmp(getPopupValue(handles.trajType), 'Concentric CRT 2D')
                    onGenerateTarget();
                end
            catch ME
                errordlg(ME.message, 'CRT settings error');
            end
        end
    end

    function onGenerateTarget(~,~)
        handles = guidata(fig);
        try
            cfg = readConfig();
            if isCrtRingSetConfig(cfg)
                crtSet = make_concentric_crt_set(makeCrtGeneratorParams(cfg, 'multi_ring_set'));
                previews = cell(crtSet.nRings,1);
                for rr = 1:crtSet.nRings
                    previews{rr} = makePreviewFromTarget(crtSet.targets{rr}, cfg);
                end
                handles.state.lastTarget = crtSet;
                handles.state.lastPreview = previews;
                plotCrtRingSetTarget(crtSet, previews, cfg);
                setReport(reportFromCrtRingSetTarget(crtSet, previews, cfg));
                setStatus(sprintf('CRT set generated: %d independent rings x %d samples/ring = %d spatial samples.', ...
                    crtSet.nRings, crtSet.NppPerRing, crtSet.totalSpatialSamples));
            else
                ktraj = makeTargetKtraj(cfg, handles.state.importedKtraj);
                preview = makePreviewFromTarget(ktraj, cfg);
                handles.state.lastTarget = ktraj;
                handles.state.lastPreview = preview;
                plotTarget(ktraj, preview, cfg);
                setReport(reportFromTarget(ktraj, preview, cfg));
                setStatus(sprintf('One compact %s target generated; target is not repeated for display/optimization.', cfg.trajType));
            end
            handles.state.lastResult = [];
            handles.state.lastFull = [];
            handles.state.lastConfig = cfg;
            guidata(fig, handles);
        catch ME
            showError(ME);
        end
    end

    function onRunOptimization(~,~)
        handles = guidata(fig);
        try
            cfg = readConfig();
            isRingSet = isCrtRingSetConfig(cfg);
            if isRingSet
                setStatus(sprintf('Optimizing CRT ring set: %d independent rings, %d samples per ring...', cfg.crt.nRings, cfg.Npp));
            else
                setStatus('Optimizing ONE compact periodic waveform; full MRSI readout = repeat this period...');
            end
            drawnow;
            sys = struct();
            sys.Gmax = cfg.Gmax_mTm * 1e-3;
            sys.Smax = cfg.Smax;
            sys.dtGrad = cfg.dtGrad_us * 1e-6;
            sys.gammaBar = cfg.gammaBar_MHzT * 1e6;
            if cfg.periodicMrsi
                acq = setup_periodic_mrsi_readout(cfg.Npp, cfg.Nspec, cfg.adcDwell_us*1e-6, ...
                    'adcDelay', cfg.adcDelay_ms*1e-3);
            else
                acq = struct();
                acq.nADC = cfg.Ntarget;
                acq.dtADC = cfg.adcDwell_us * 1e-6;
                acq.spectralBW = 1 / acq.dtADC;
                acq.readoutTime = (cfg.Ntarget - 1) * acq.dtADC;
                acq.adcDelay = cfg.adcDelay_ms * 1e-3;
            end
            opt = struct();
            opt.mode = cfg.mode;
            opt.symmetry = cfg.symmetry;
            if cfg.periodicMrsi
                % Periodic MRSI is optimized as one compact waveform period.
                % The period is repeated Nspec times, so the last-to-first
                % gradient transition must satisfy cyclic slew limits. Exact
                % equality G(end)=G(1) is optional. For circular CRT rings,
                % hard C0/C1 equality can substantially distort the target even
                % when the cyclic direct gradient is hardware feasible, so the
                % CRT default is target-fidelity mode: cyclic slew + closure,
                % but no hard C0/C1 equality.
                opt.forceGStartZero = false;
                opt.forceGEndZero = false;
                opt.forceGPeriodicEqual = true;
                opt.forceSlewPeriodicEqual = true;
                if strcmp(cfg.trajType, 'Concentric CRT 2D')
                    opt.forceGPeriodicEqual = cfg.crt.forceHardC0C1;
                    opt.forceSlewPeriodicEqual = cfg.crt.forceHardC0C1;
                end
            else
                opt.forceGStartZero = true;
                opt.forceGEndZero = true;
                opt.forceGPeriodicEqual = false;
                opt.forceSlewPeriodicEqual = false;
            end
            opt.periodic = cfg.periodicMrsi;
            opt.Npp = cfg.Npp;
            opt.safetyMargin = cfg.safety;
            opt.maxControlPoints = cfg.maxControl;
            opt.lambdaSlew = cfg.lambdaSlew;
            opt.lambdaSmooth = cfg.lambdaSmooth;
            opt.optimizerDisplay = 'off';

            if isRingSet
                pSet = makeCrtGeneratorParams(cfg, 'multi_ring_set');
                setOpts = struct();
                setOpts.usePreGradient = cfg.crt.usePreGradient;
                setOpts.preGradientSamples = cfg.crt.preGradientSamples;
                setOpts.usePostGradient = cfg.crt.usePostGradient;
                setOpts.postGradientSamples = cfg.crt.postGradientSamples;
                setOpts.Nspec = cfg.Nspec;
                result = optimize_concentric_crt_set(pSet, sys, acq, opt, setOpts);
                full = [];
                lastTarget = struct();
                lastTarget.mode = 'multi_ring_set';
                lastTarget.NppPerRing = result.NppPerRing;
                lastTarget.nRings = result.nRings;
                lastTarget.totalSpatialSamples = result.totalSpatialSamples;
                lastTarget.radii = result.radii;
                lastTarget.targets = result.targets;
                lastTarget.targetStack = result.targetStack;
            else
                ktraj = makeTargetKtraj(cfg, handles.state.importedKtraj);
                result = nc_mrsi_gradopt(ktraj, sys, acq, opt);
                if cfg.periodicMrsi
                    % For CRT single-ring readouts, the ADC may start on a nonzero
                    % ring with nonzero tangent gradient.  Do not force G(1)=0
                    % inside the ADC period.  Instead, add a non-ADC pre-gradient
                    % before the ring; it starts from zero gradient, reaches the
                    % ring start k-space location, and ends at result.G(1,:).
                    if strcmp(cfg.trajType, 'Concentric CRT 2D') && isfield(cfg.crt,'usePreGradient') && cfg.crt.usePreGradient
                        Npre = cfg.crt.preGradientSamples;
                        if Npre <= 0
                            Npre = [];
                        end
                        result = add_pre_gradient_to_periodic_result(result, Npre);
                    end
                    if strcmp(cfg.trajType, 'Concentric CRT 2D') && ...
                            isfield(cfg.crt,'usePostGradient') && cfg.crt.usePostGradient
                        Npost = cfg.crt.postGradientSamples;
                        if Npost <= 0
                            Npost = [];
                        end
                        result = add_post_gradient_to_periodic_result(result,Npost);
                    end
                    result.periodic = makePeriodicInfo(cfg, result);
                    full = expand_periodic_readout(result, cfg.Nspec);
                else
                    full = [];
                end
                lastTarget = ktraj;
            end

            handles.state.lastTarget = lastTarget;
            handles.state.lastPreview = [];
            handles.state.lastResult = result;
            handles.state.lastFull = full;
            handles.state.lastConfig = cfg;
            guidata(fig, handles);
            if isRingSet
                plotCrtRingSetResult(result, cfg);
                setReportFromCrtRingSetResult(result, cfg);
                if result.summary.allFeasible
                    setStatus(sprintf('CRT set finished: all %d real pre-ring-post modules are feasible; each ring contains %d ADC samples.', ...
                        result.nRings, result.NppPerRing));
                else
                    setStatus('CRT set finished, but at least one readout/pre/post module failed feasibility. See report.');
                end
            else
                plotResult(result, cfg);
                setReportFromResult(result, cfg, full);
                if result.report.isFeasible
                    setStatus('Optimization finished for one periodic period. Full readout = repeat identical G_period Nspec times.');
                else
                    setStatus('Optimization finished, but feasibility check failed. See report.');
                end
            end
        catch ME
            showError(ME);
        end
    end

    function onKErrorPopup(~,~)
        handles = guidata(fig);
        try
            if ~isempty(handles.state.lastResult)
                if isCrtRingSetResult(handles.state.lastResult)
                    r = handles.state.lastResult.rings(end);
                    showKErrorPopup(r.ktraj_target, r.ktraj_actual, r.time_grad);
                else
                    showKErrorPopup(handles.state.lastResult.ktraj_target, handles.state.lastResult.ktraj_actual, handles.state.lastResult.time_grad);
                end
            elseif ~isempty(handles.state.lastTarget) && ~isempty(handles.state.lastPreview)
                if isstruct(handles.state.lastTarget) && isfield(handles.state.lastTarget,'mode') && strcmp(handles.state.lastTarget.mode,'multi_ring_set')
                    rr = handles.state.lastTarget.nRings;
                    showKErrorPopup(handles.state.lastTarget.targets{rr}, handles.state.lastPreview{rr}.ktraj_actual, handles.state.lastPreview{rr}.time);
                else
                    showKErrorPopup(handles.state.lastTarget, handles.state.lastPreview.ktraj_actual, handles.state.lastPreview.time);
                end
            else
                setStatus('No target/result available for error popup.');
            end
        catch ME
            showError(ME);
        end
    end

    function onExportCsv(~,~)
        handles = guidata(fig);
        if isempty(handles.state.lastResult)
            setStatus('No optimized result to export. Run optimization first.');
            return;
        end
        [fileName, pathName] = uiputfile('gradopt_period_result.csv', 'Export compact period CSV');
        if isequal(fileName,0)
            return;
        end
        try
            if isCrtRingSetResult(handles.state.lastResult)
                export_crt_ring_set_csv(handles.state.lastResult, fullfile(pathName, fileName));
                setStatus(sprintf('Exported all CRT rings to combined CSV: %s', fullfile(pathName, fileName)));
            else
                export_csv(handles.state.lastResult, fullfile(pathName, fileName));
                setStatus(sprintf('Exported compact-period CSV: %s', fullfile(pathName, fileName)));
            end
        catch ME
            showError(ME);
        end
    end

    function onSaveMat(~,~)
        handles = guidata(fig);
        if isempty(handles.state.lastResult)
            setStatus('No optimized result to save. Run optimization first.');
            return;
        end
        [fileName, pathName] = uiputfile('gradopt_periodic_mrsi_result.mat', 'Save MAT result');
        if isequal(fileName,0)
            return;
        end
        try
            result = handles.state.lastResult; %#ok<NASGU>
            full = handles.state.lastFull; %#ok<NASGU>
            cfg = handles.state.lastConfig; %#ok<NASGU>
            save(fullfile(pathName, fileName), 'result', 'full', 'cfg');
            setStatus(sprintf('Saved MAT: %s', fullfile(pathName, fileName)));
        catch ME
            showError(ME);
        end
    end

    function onPulseqVerify(~,~)
        handles = guidata(fig);
        if isempty(handles.state.lastResult)
            setStatus('No optimized result. Run optimization first.');
            return;
        end
        if ~isCrtRingSetResult(handles.state.lastResult)
            setStatus('Pulseq verify button currently requires CRT multi_ring_set.');
            return;
        end
        outputDir = uigetdir(pwd,'Select Pulseq export directory');
        if isequal(outputDir,0)
            return;
        end
        try
            setStatus('Writing and reading back compact/full-FID Pulseq files...');
            drawnow;
            seqOpts = struct('compatibility','1.4.1');
            output = run_crt_pulseq_roundtrip( ...
                handles.state.lastResult,outputDir,seqOpts);
            if output.validation.overallPass
                setStatus(sprintf('Pulseq round-trip PASS. Reports: %s',outputDir));
            else
                setStatus(sprintf('Pulseq round-trip FAILED. Inspect reports: %s',outputDir));
            end
        catch ME
            showError(ME);
        end
    end

    function onResetView(~,~)
        handles = guidata(fig);
        try
            if ~isempty(handles.state.lastResult)
                if isCrtRingSetResult(handles.state.lastResult)
                    plotCrtRingSetResult(handles.state.lastResult, handles.state.lastConfig);
                else
                    plotResult(handles.state.lastResult, handles.state.lastConfig);
                end
            elseif ~isempty(handles.state.lastTarget)
                if isstruct(handles.state.lastTarget) && isfield(handles.state.lastTarget,'mode') && strcmp(handles.state.lastTarget.mode,'multi_ring_set')
                    plotCrtRingSetTarget(handles.state.lastTarget, handles.state.lastPreview, handles.state.lastConfig);
                else
                    plotTarget(handles.state.lastTarget, handles.state.lastPreview, handles.state.lastConfig);
                end
            end
            setStatus('View reset.');
        catch ME
            showError(ME);
        end
    end

    function updateNucleusGamma()
        handles = guidata(fig);
        values = get(handles.nucleus, 'String');
        nuc = values{get(handles.nucleus, 'Value')};
        switch nuc
            case '31P'
                gammaMHz = 17.235;
            case '1H'
                gammaMHz = 42.57747892;
            case '13C'
                gammaMHz = 10.7084;
            case '23Na'
                gammaMHz = 11.262;
            otherwise
                return;
        end
        set(handles.gammaBarMHz, 'String', num2str(gammaMHz, '%.9g'));
    end

    function cfg = readConfig()
        handles = guidata(fig);
        updateDerivedTiming();
        cfg = struct();
        cfg.periodicMrsi = get(handles.periodicMrsi, 'Value') ~= 0;
        cfg.trajType = getPopupValue(handles.trajType);
        if ~isfield(handles.state,'crt') || isempty(handles.state.crt)
            handles.state.crt = defaultCrtParams();
            guidata(fig, handles);
        end
        handles.state.crt = ensureCrtDefaults(handles.state.crt);
        cfg.crt = handles.state.crt;
        guidata(fig, handles);
        cfg.Ntarget = readPositiveInteger(handles.Ntarget, 'Target samples/period');
        cfg.Kmax = readPositiveDouble(handles.Kmax, 'Kmax');
        cfg.nRadial = readPositiveDouble(handles.nRadial, 'Radial oscillations');
        cfg.nAngular = readPositiveDouble(handles.nAngular, 'Angular rotations');
        cfg.phiDeg = readDouble(handles.phiDeg, 'Phi');
        cfg.betaDeg = readDouble(handles.betaDeg, 'Beta');
        cfg.workspaceVar = strtrim(get(handles.workspaceVar, 'String'));
        cfg.Gmax_mTm = readPositiveDouble(handles.Gmax, 'Gmax');
        cfg.Smax = readPositiveDouble(handles.Smax, 'Smax');
        cfg.dtGrad_us = readPositiveDouble(handles.dtGradUs, 'Gradient raster');
        cfg.gammaBar_MHzT = readPositiveDouble(handles.gammaBarMHz, 'gamma/2pi');
        cfg.Npp = readPositiveInteger(handles.Npp, 'Npp');
        cfg.Nspec = readPositiveInteger(handles.Nspec, 'Nspec');
        cfg.adcDwell_us = readPositiveDouble(handles.adcDwellUs, 'ADC dwell');
        cfg.dtADC = cfg.adcDwell_us * 1e-6;
        cfg.nADCtotal = cfg.Npp * cfg.Nspec;
        cfg.periodTime = cfg.Npp * cfg.dtADC;
        cfg.derivedSpectralBW = 1 / cfg.periodTime;
        cfg.spectralResolution = cfg.derivedSpectralBW / cfg.Nspec;
        cfg.readoutTimeTotal = cfg.nADCtotal * cfg.dtADC;
        cfg.adcDelay_ms = readNonnegativeDouble(handles.adcDelayMs, 'ADC delay');
        cfg.mode = getPopupValue(handles.mode);
        cfg.symmetry = getPopupValue(handles.symmetry);
        cfg.safety = readPositiveDouble(handles.safety, 'Safety margin');
        cfg.maxControl = readPositiveInteger(handles.maxControl, 'Max control points');
        cfg.lambdaSlew = readNonnegativeDouble(handles.lambdaSlew, 'lambda slew');
        cfg.lambdaSmooth = readNonnegativeDouble(handles.lambdaSmooth, 'lambda smooth');
        if cfg.safety > 1
            error('Safety margin should be <= 1.');
        end
        if cfg.periodicMrsi
            % In periodic MRSI, one target period contains exactly Npp ADC
            % samples. Keep the legacy Ntarget field synchronized to avoid
            % accidental Ntarget/Npp mismatch, e.g. Ntarget=160 but Npp=96.
            cfg.Ntarget = cfg.Npp;
            set(handles.Ntarget, 'String', num2str(cfg.Npp));
            if abs(cfg.dtGrad_us - cfg.adcDwell_us) > 1e-9
                % This is allowed, but the GUI tells the user because Npp is normally
                % interpreted directly as both ADC and gradient samples per period.
                setStatus('Note: gradient raster differs from ADC dwell; target is optimized on gradient raster after resampling.');
            end
        elseif isCrtRingSetConfig(cfg)
            error('CRT multi_ring_set requires Periodic MRSI mode because each ring is one compact spectral period.');
        end
    end

    function ktraj = makeTargetKtraj(cfg, importedKtraj)
        if cfg.periodicMrsi
            N = cfg.Npp;  % compact period length; this is the key correction.
        else
            N = cfg.Ntarget;
        end
        switch cfg.trajType
            case 'Rosette 2D'
                if cfg.periodicMrsi
                    p.Npp = N; p.Kmax = cfg.Kmax; p.nRadial = cfg.nRadial; p.nAngular = cfg.nAngular; p.beta = cfg.betaDeg*pi/180; p.shape = 'petalute_paper';
                    ktraj = make_periodic_rosette_2d(p);
                else
                    p.N = N; p.Kmax = cfg.Kmax; p.nRadial = cfg.nRadial; p.nAngular = cfg.nAngular;
                    ktraj = make_rosette_2d(p);
                end
            case 'Rosette 3D'
                if cfg.periodicMrsi
                    p.Npp = N; p.Kmax = cfg.Kmax; p.nRadial = cfg.nRadial; p.nAngular = cfg.nAngular; p.phi = cfg.phiDeg*pi/180; p.beta = cfg.betaDeg*pi/180; p.shape = 'petalute_paper';
                    ktraj = make_periodic_rosette_3d(p);
                else
                    p.N = N; p.Kmax = cfg.Kmax; p.nRadial = cfg.nRadial; p.nAngular = cfg.nAngular; p.phi = cfg.phiDeg*pi/180;
                    ktraj = make_rosette_3d(p);
                end
            case 'Spiral 2D'
                p.N = N; p.Kmax = cfg.Kmax; p.nTurns = cfg.nAngular;
                ktraj = make_spiral(p);
            case 'Concentric CRT 2D'
                % CRT uses a dedicated settings dialog because its parameters are
                % not the same as rosette radial/angular oscillations.
                % Main GUI fields still define Npp, Kmax, beta, hardware, and MRSI timing.
                if strcmp(cfg.crt.mode,'multi_ring_set')
                    error('multi_ring_set must be generated with make_concentric_crt_set; the GUI handles this mode as a batch.');
                end
                p = makeCrtGeneratorParams(cfg, cfg.crt.mode);
                p.Npp = N;
                ktraj = make_periodic_crt_2d(p);
            case 'Radial 2D'
                p.N = N; p.Kmax = cfg.Kmax; p.angle = cfg.phiDeg*pi/180;
                ktraj = make_radial(p);
            case 'Cones 3D'
                p.N = N; p.Kmax = cfg.Kmax; p.nTurns = cfg.nAngular; p.coneAngle = max(0.001, cfg.phiDeg*pi/180);
                ktraj = make_cones(p);
            case 'Workspace/CSV ktraj'
                if ~isempty(importedKtraj)
                    ktraj = importedKtraj;
                elseif ~isempty(cfg.workspaceVar)
                    ktraj = evalin('base', cfg.workspaceVar);
                else
                    error('No workspace variable name or CSV trajectory was provided.');
                end
                if cfg.periodicMrsi
                    if size(ktraj,1) < cfg.Npp
                        error('Imported ktraj has fewer samples than Npp. For periodic MRSI, the compact period must contain at least Npp samples.');
                    elseif size(ktraj,1) > cfg.Npp
                        ktraj = ktraj(1:cfg.Npp,:);
                    end
                end
            otherwise
                error('Unknown trajectory type: %s', cfg.trajType);
        end
        ktraj = validate_ktraj_input(ktraj);
    end

    function p = makeCrtGeneratorParams(cfg, modeName)
        crt = cfg.crt;
        p = struct();
        p.Npp = cfg.Npp;
        p.Kmax = cfg.Kmax;
        p.nRings = max(1, round(crt.nRings));
        p.ringIndex = max(1, round(crt.ringIndex));
        p.nTurnsPerRing = crt.nTurnsPerRing;
        p.phase = cfg.betaDeg*pi/180;
        p.mode = modeName;
        p.transitionFraction = crt.transitionFraction;
        p.alternateDirection = crt.alternateDirection;
        if isfield(crt,'rMin') && isfinite(crt.rMin) && crt.rMin > 0
            p.rMin = crt.rMin;
        end
    end

    function preview = makePreviewFromTarget(ktraj, cfg)
        dt = cfg.dtADC;
        gammaBar = cfg.gammaBar_MHzT * 1e6;
        if cfg.periodicMrsi
            G = periodicGradientFromK(ktraj, dt, gammaBar);
            optsPreview = struct('gammaBar', gammaBar, 'dtGrad', dt);
            kactual = integrate_periodic_gradient_samples(G, optsPreview, ktraj(1,:));
        else
            G = gradientFromK(ktraj, dt, gammaBar);
            kactual = kFromGradient(G, dt, gammaBar, ktraj(1,:));
        end
        if cfg.periodicMrsi
            S = compute_cyclic_slew(G, dt);
        else
            S = compute_slew(G, dt);
        end
        preview = struct();
        preview.G = G;
        preview.S = S;
        preview.ktraj_actual = kactual;
        preview.time = (0:size(ktraj,1)-1).' * dt;
    end

    function info = makePeriodicInfo(cfg, result)
        closure = check_periodic_closure(result.ktraj_actual, result.G, result.opts);
        info = struct();
        info.Npp = cfg.Npp;
        info.Nspec = cfg.Nspec;
        info.nADCtotal = cfg.nADCtotal;
        info.adcDwell = cfg.dtADC;
        info.periodTime = cfg.periodTime;
        info.spectralBW = cfg.derivedSpectralBW;
        info.spectralResolution = cfg.spectralResolution;
        info.totalReadoutTime = cfg.readoutTimeTotal;
        info.closure = closure;
    end

    function plotTarget(ktraj, preview, cfg)
        handles = guidata(fig);
        plotKComponentsOnAxes(handles.axKcomp, ktraj, preview.ktraj_actual, preview.time, 'One-period kx/ky/kz target and direct preview');
        plotKspaceOnAxes(handles.axKspace, ktraj, preview.ktraj_actual, 'One-period k-space');
        plotGradientPreviewOnAxes(handles.axG, preview, cfg, 'Direct gradient preview from one period');
        plotSlewPreviewOnAxes(handles.axS, preview, cfg, 'Direct slew preview from one period');
        axes(handles.axErr); cla(handles.axErr);
        e = preview.ktraj_actual - ktraj;
        en = sqrt(sum(e.^2,2));
        plot(handles.axErr, preview.time*1e3, en, 'LineWidth',1.0);
        grid(handles.axErr,'on'); xlabel(handles.axErr,'time (ms)'); ylabel(handles.axErr,'|dk|'); title(handles.axErr,'direct k error');
    end

    function plotResult(result, cfg)
        handles = guidata(fig);
        plotKComponentsOnAxes(handles.axKcomp, result.ktraj_target, result.ktraj_actual, result.time_grad, 'One-period kx/ky/kz target vs actual');
        plotKspaceOnAxes(handles.axKspace, result.ktraj_target, result.ktraj_actual, 'One-period k-space');
        plotGradientOnAxes(handles.axG, result);
        plotSlewOnAxes(handles.axS, result);
        plotErrorOnAxes(handles.axErr, result);
        if nargin > 1 && cfg.periodicMrsi
            title(handles.axKcomp, sprintf('One period: Npp=%d, Nspec=%d, total ADC=%d', cfg.Npp, cfg.Nspec, cfg.nADCtotal));
        end
    end

    function plotCrtRingSetTarget(crtSet, previews, cfg)
        handles = guidata(fig);
        outer = crtSet.nRings;
        plotKComponentsOnAxes(handles.axKcomp, crtSet.targets{outer}, ...
            previews{outer}.ktraj_actual, previews{outer}.time, ...
            sprintf('Outer-ring preview; each of %d rings has Npp=%d', crtSet.nRings, crtSet.NppPerRing));

        colors = lines(crtSet.nRings);
        axes(handles.axKspace); cla(handles.axKspace); hold(handles.axKspace,'on');
        hTarget = [];
        for rr = 1:crtSet.nRings
            k = crtSet.targets{rr};
            hThis = plot(handles.axKspace, k(:,1), k(:,2), '--', ...
                'Color',colors(rr,:), 'LineWidth',1.0);
            if isempty(hTarget)
                hTarget = hThis;
            end
        end
        axis(handles.axKspace,'equal'); grid(handles.axKspace,'on');
        xlabel(handles.axKspace,'kx (cycles/m)'); ylabel(handles.axKspace,'ky (cycles/m)');
        title(handles.axKspace,sprintf('CRT target set: %d independent ADC rings',crtSet.nRings));
        if ~isempty(hTarget)
            legend(handles.axKspace,hTarget,{'ring target (ADC)'},'Location','best');
        end
        hold(handles.axKspace,'off');

        axes(handles.axG); cla(handles.axG); hold(handles.axG,'on');
        axes(handles.axS); cla(handles.axS); hold(handles.axS,'on');
        axes(handles.axErr); cla(handles.axErr); hold(handles.axErr,'on');
        for rr = 1:crtSet.nRings
            pv = previews{rr};
            tms = pv.time * 1e3;
            plot(handles.axG, tms, sqrt(sum(pv.G.^2,2))*1e3, 'Color',colors(rr,:), 'LineWidth',1.0);
            plot(handles.axS, tms(1:size(pv.S,1)), sqrt(sum(pv.S.^2,2)), 'Color',colors(rr,:), 'LineWidth',1.0);
            e = pv.ktraj_actual - crtSet.targets{rr};
            plot(handles.axErr, tms, sqrt(sum(e.^2,2)), 'Color',colors(rr,:), 'LineWidth',1.0);
        end
        yline_compat(handles.axG, cfg.Gmax_mTm*cfg.safety, ':');
        yline_compat(handles.axS, cfg.Smax*cfg.safety, ':');
        grid(handles.axG,'on'); xlabel(handles.axG,'time (ms)'); ylabel(handles.axG,'|G| (mT/m)');
        title(handles.axG,'Direct gradient norm for each independent ring');
        grid(handles.axS,'on'); xlabel(handles.axS,'time (ms)'); ylabel(handles.axS,'|S| (T/m/s)');
        title(handles.axS,'Direct slew norm for each independent ring');
        grid(handles.axErr,'on'); xlabel(handles.axErr,'time (ms)'); ylabel(handles.axErr,'|dk|');
        title(handles.axErr,'Direct k error by ring');
        hold(handles.axG,'off'); hold(handles.axS,'off'); hold(handles.axErr,'off');
    end

    function plotCrtRingSetResult(resultSet, cfg)
        handles = guidata(fig);
        outer = resultSet.nRings;
        outerResult = resultSet.rings(outer);
        plotKComponentsOnAxes(handles.axKcomp, outerResult.ktraj_target, ...
            outerResult.ktraj_actual, outerResult.time_grad, ...
            sprintf('Outer-ring result; %d rings x Npp=%d', resultSet.nRings, resultSet.NppPerRing));

        colors = lines(resultSet.nRings);
        axes(handles.axKspace); cla(handles.axKspace); hold(handles.axKspace,'on');
        hTarget = [];
        hActual = [];
        for rr = 1:resultSet.nRings
            r = resultSet.rings(rr);
            hThisTarget = plot(handles.axKspace, r.ktraj_target(:,1), r.ktraj_target(:,2), '--', ...
                'Color',colors(rr,:), 'LineWidth',0.9);
            if isfield(r,'sequence') && isfield(r.sequence,'ktraj_actual')
                % Include the explicit readout-closure point at the first
                % post-gradient sample. These points all come from one
                % continuous reintegration of sequence.G.
                adcIdx = r.sequence.adcStartIndex: ...
                    r.sequence.readoutClosureIndex;
                kAdc = r.sequence.ktraj_actual(adcIdx,1:2);
            else
                kAdc = r.ktraj_actual(:,1:2);
            end
            hThisActual = plot(handles.axKspace, kAdc(:,1), kAdc(:,2), '-', ...
                'Color',colors(rr,:), 'LineWidth',1.1);
            if isempty(hTarget)
                hTarget = hThisTarget;
                hActual = hThisActual;
            end
        end
        hPre = [];
        hPost = [];
        for rr = 1:resultSet.nRings
            r = resultSet.rings(rr);
            if isfield(r,'sequence') && isfield(r.sequence,'ktraj_actual')
                p = r.sequence.ktraj_actual( ...
                    1:r.sequence.adcStartIndex,1:2);
                hp = plot(handles.axKspace,p(:,1),p(:,2),':', ...
                    'Color',colors(rr,:),'LineWidth',1.15);
                if isempty(hPre); hPre = hp; end
                p = r.sequence.ktraj_actual( ...
                    r.sequence.readoutClosureIndex:end,1:2);
                hp = plot(handles.axKspace,p(:,1),p(:,2),'-.', ...
                    'Color',colors(rr,:),'LineWidth',1.25);
                if isempty(hPost); hPost = hp; end
            end
        end
        hOrigin = plot(handles.axKspace,0,0,'p','Color',[0 0.45 0.10], ...
            'MarkerFaceColor',[0.15 0.75 0.25], ...
            'MarkerSize',9,'LineWidth',1.0);
        axis(handles.axKspace,'equal'); grid(handles.axKspace,'on');
        xlabel(handles.axKspace,'kx (cycles/m)'); ylabel(handles.axKspace,'ky (cycles/m)');
        title(handles.axKspace,'All CRT rings: real k=0 \rightarrow pre \rightarrow ADC ring \rightarrow post \rightarrow k=0');
        if ~isempty(hPre) && ~isempty(hPost)
            legend(handles.axKspace, ...
                [hTarget hActual hPre hPost hOrigin], ...
                {'ring target (ADC)','reintegrated ring + closure', ...
                 'reintegrated pre-gradient (non-ADC)', ...
                 'reintegrated post-gradient (non-ADC)', ...
                 'start/end: k=0'}, ...
                'Location','best');
        else
            legend(handles.axKspace,[hTarget hActual], ...
                {'ring target (ADC)','ring actual (ADC)'},'Location','best');
        end
        hold(handles.axKspace,'off');

        axes(handles.axG); cla(handles.axG); hold(handles.axG,'on');
        axes(handles.axS); cla(handles.axS); hold(handles.axS,'on');
        axes(handles.axErr); cla(handles.axErr); hold(handles.axErr,'on');
        for rr = 1:resultSet.nRings
            r = resultSet.rings(rr);
            if isfield(r,'sequence') && isfield(r.sequence,'G')
                tms = r.sequence.time_grad*1e3;
                gPlot = max(abs(r.sequence.G),[],2)*1e3;
                sPlot = max(abs(r.sequence.S),[],2);
                tS = tms(1:size(r.sequence.S,1));
            else
                tms = r.time_grad*1e3;
                gPlot = max(abs(r.G),[],2)*1e3;
                sPlot = max(abs(r.S),[],2);
                tS = tms(1:size(r.S,1));
            end
            plot(handles.axG,tms,gPlot,'Color',colors(rr,:),'LineWidth',1.0);
            plot(handles.axS,tS,sPlot,'Color',colors(rr,:),'LineWidth',1.0);
            e = r.ktraj_actual - r.ktraj_target;
            plot(handles.axErr,r.time_grad*1e3,sqrt(sum(e.^2,2)), ...
                'Color',colors(rr,:),'LineWidth',1.0);
        end
        yline_compat(handles.axG, cfg.Gmax_mTm*cfg.safety, ':');
        yline_compat(handles.axS, cfg.Smax*cfg.safety, ':');
        grid(handles.axG,'on'); xlabel(handles.axG,'time relative to ADC start (ms)'); ylabel(handles.axG,'max |G_{axis}| (mT/m)');
        title(handles.axG,'Real complete-module gradient by ring');
        grid(handles.axS,'on'); xlabel(handles.axS,'time relative to ADC start (ms)'); ylabel(handles.axS,'max |S_{axis}| (T/m/s)');
        title(handles.axS,'Real complete-module slew by ring');
        grid(handles.axErr,'on'); xlabel(handles.axErr,'time (ms)'); ylabel(handles.axErr,'|dk|');
        title(handles.axErr,'Optimized k error by ring');
        hold(handles.axG,'off'); hold(handles.axS,'off'); hold(handles.axErr,'off');
    end

    function plotKComponentsOnAxes(ax, ktarget, kactual, timeVec, ttl)
        axes(ax); cla(ax); hold(ax,'on');
        D = size(ktarget,2);
        labsBase = {'kx','ky','kz'};
        if isempty(timeVec)
            x = (1:size(ktarget,1)).';
            xlab = 'sample in period';
        else
            x = timeVec(:) * 1e3;
            xlab = 'time in period (ms)';
        end
        for d = 1:D
            plot(ax, x, ktarget(:,d), '--', 'LineWidth',1.0);
        end
        if ~isempty(kactual)
            for d = 1:min(D,size(kactual,2))
                plot(ax, x(1:size(kactual,1)), kactual(:,d), '-', 'LineWidth',1.1);
            end
        end
        labs = {};
        for d = 1:D
            labs{end+1} = [labsBase{min(d,3)} ' target']; %#ok<AGROW>
        end
        if ~isempty(kactual)
            for d = 1:D
                labs{end+1} = [labsBase{min(d,3)} ' actual']; %#ok<AGROW>
            end
        end
        grid(ax,'on'); xlabel(ax,xlab); ylabel(ax,'k (cycles/m)'); title(ax,ttl);
        legend(ax, labs, 'Location','best'); hold(ax,'off');
    end

    function plotKspaceOnAxes(ax, ktarget, kactual, ttl)
        axes(ax); cla(ax); hold(ax,'on');
        if size(ktarget,2) >= 3
            plot3(ax, ktarget(:,1), ktarget(:,2), ktarget(:,3), '--', 'LineWidth', 1.0);
            if ~isempty(kactual)
                plot3(ax, kactual(:,1), kactual(:,2), kactual(:,3), '-', 'LineWidth', 1.2);
                legend(ax, {'target','actual'}, 'Location','best');
            else
                legend(ax, {'target'}, 'Location','best');
            end
            xlabel(ax,'kx'); ylabel(ax,'ky'); zlabel(ax,'kz'); view(ax,3);
        elseif size(ktarget,2) == 2
            plot(ax, ktarget(:,1), ktarget(:,2), '--', 'LineWidth', 1.0);
            if ~isempty(kactual)
                plot(ax, kactual(:,1), kactual(:,2), '-', 'LineWidth', 1.2);
                legend(ax, {'target','actual'}, 'Location','best');
            else
                legend(ax, {'target'}, 'Location','best');
            end
            xlabel(ax,'kx'); ylabel(ax,'ky');
        else
            plot(ax, ktarget(:,1), '--', 'LineWidth', 1.0);
            if ~isempty(kactual)
                plot(ax, kactual(:,1), '-', 'LineWidth', 1.2);
                legend(ax, {'target','actual'}, 'Location','best');
            else
                legend(ax, {'target'}, 'Location','best');
            end
            xlabel(ax,'sample'); ylabel(ax,'k');
        end
        axis(ax,'equal'); grid(ax,'on'); title(ax,ttl); hold(ax,'off');
    end

    function plotErrorOnAxes(ax, result)
        axes(ax); cla(ax);
        e = result.ktraj_actual - result.ktraj_target;
        en = sqrt(sum(e.^2,2));
        plot(ax, result.time_grad*1e3, en, 'LineWidth',1.1);
        grid(ax,'on'); xlabel(ax,'time in period (ms)'); ylabel(ax,'|dk|'); title(ax,'k-space error');
    end

    function plotGradientPreviewOnAxes(ax, preview, cfg, ttl)
        axes(ax); cla(ax); hold(ax,'on');
        GmT = preview.G * 1e3;
        labs = axisLabels(size(GmT,2), 'G');
        for d = 1:size(GmT,2)
            plot(ax, preview.time*1e3, GmT(:,d), 'LineWidth',1.1);
        end
        yline_compat(ax, cfg.Gmax_mTm*cfg.safety, ':');
        yline_compat(ax, -cfg.Gmax_mTm*cfg.safety, ':');
        grid(ax,'on'); xlabel(ax,'time in period (ms)'); ylabel(ax,'G (mT/m)'); title(ax,ttl);
        legend(ax, labs, 'Location','best'); hold(ax,'off');
    end

    function plotSlewPreviewOnAxes(ax, preview, cfg, ttl)
        axes(ax); cla(ax); hold(ax,'on');
        tS = preview.time(1:min(numel(preview.time), size(preview.S,1))) * 1e3;
        if numel(tS) < size(preview.S,1)
            tS = (0:size(preview.S,1)-1).' * cfg.dtADC * 1e3;
        end
        labs = axisLabels(size(preview.S,2), 'S');
        for d = 1:size(preview.S,2)
            plot(ax, tS, preview.S(:,d), 'LineWidth',1.1);
        end
        yline_compat(ax, cfg.Smax*cfg.safety, ':');
        yline_compat(ax, -cfg.Smax*cfg.safety, ':');
        grid(ax,'on'); xlabel(ax,'time in period (ms)'); ylabel(ax,'S (T/m/s)'); title(ax,ttl);
        legend(ax, labs, 'Location','best'); hold(ax,'off');
    end

    function plotGradientOnAxes(ax, result)
        axes(ax); cla(ax); hold(ax,'on');
        GmT = result.G * 1e3;
        labs = axisLabels(size(GmT,2), 'G');
        if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'G') && ~isempty(result.pre.G)
            Gpre_mT = result.pre.G * 1e3;
            tPre = result.pre.time_grad * 1e3;
            for d = 1:size(Gpre_mT,2)
                plot(ax, tPre, Gpre_mT(:,d), ':', 'LineWidth',1.1);
            end
            xline_compat(ax, 0, ':');
        end
        for d = 1:size(GmT,2)
            plot(ax, result.time_grad*1e3, GmT(:,d), 'LineWidth',1.1);
        end
        if isfield(result,'post') && isstruct(result.post) && isfield(result.post,'G') && ~isempty(result.post.G)
            Gpost_mT = result.post.G*1e3;
            tPost = (size(result.G,1)+(0:size(Gpost_mT,1)-1)).' * ...
                result.opts.dtGrad*1e3;
            for d = 1:size(Gpost_mT,2)
                plot(ax,tPost,Gpost_mT(:,d),'-.','LineWidth',1.1);
            end
        end
        yline_compat(ax, result.opts.Guse*1e3, ':');
        yline_compat(ax, -result.opts.Guse*1e3, ':');
        grid(ax,'on'); xlabel(ax,'time relative to ADC start (ms)'); ylabel(ax,'G (mT/m)');
        if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'G') && ~isempty(result.pre.G)
            title(ax,'Real complete module: pre-gradient + ADC ring + post-gradient');
        else
            title(ax,'Optimized one-period gradient waveform');
        end
        legend(ax, labs, 'Location','best'); hold(ax,'off');
    end

    function plotSlewOnAxes(ax, result)
        axes(ax); cla(ax); hold(ax,'on');
        if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'S') && ~isempty(result.pre.S)
            tPreS = result.pre.time_grad(1:size(result.pre.S,1)) * 1e3;
            for d = 1:size(result.pre.S,2)
                plot(ax, tPreS, result.pre.S(:,d), ':', 'LineWidth',1.1);
            end
            xline_compat(ax, 0, ':');
        end
        tS = result.time_grad(1:min(numel(result.time_grad), size(result.S,1))) * 1e3;
        if numel(tS) < size(result.S,1)
            tS = (0:size(result.S,1)-1).' * result.opts.dtGrad * 1e3;
        end
        labs = axisLabels(size(result.S,2), 'S');
        for d = 1:size(result.S,2)
            plot(ax, tS, result.S(:,d), 'LineWidth',1.1);
        end
        if isfield(result,'post') && isstruct(result.post) && isfield(result.post,'S') && ~isempty(result.post.S)
            tPostS = (size(result.G,1)+(0:size(result.post.S,1)-1)).' * ...
                result.opts.dtGrad*1e3;
            for d = 1:size(result.post.S,2)
                plot(ax,tPostS,result.post.S(:,d),'-.','LineWidth',1.1);
            end
        end
        yline_compat(ax, result.opts.Suse, ':');
        yline_compat(ax, -result.opts.Suse, ':');
        grid(ax,'on'); xlabel(ax,'time relative to ADC start (ms)'); ylabel(ax,'S (T/m/s)');
        if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'S') && ~isempty(result.pre.S)
            title(ax,'Real complete-module slew: pre + cyclic readout + post');
        else
            title(ax,'Optimized one-period slew rate');
        end
        legend(ax, labs, 'Location','best'); hold(ax,'off');
    end

    function linesOut = reportFromCrtRingSetTarget(crtSet, previews, cfg)
        linesOut = {};
        linesOut{end+1} = 'Complete CRT target set generated';
        linesOut{end+1} = 'Definition: one ring = one compact period';
        linesOut{end+1} = sprintf('Rings: %d', crtSet.nRings);
        linesOut{end+1} = sprintf('Npp per ring: %d', crtSet.NppPerRing);
        linesOut{end+1} = sprintf('Total spatial samples: %d = nRings*Npp', crtSet.totalSpatialSamples);
        linesOut{end+1} = sprintf('Period duration per ring: %.6g ms', cfg.periodTime*1e3);
        linesOut{end+1} = sprintf('Nspec repetitions per ring/FID: %d', cfg.Nspec);
        linesOut{end+1} = sprintf('ADC samples per ring FID: %d', cfg.nADCtotal);
        linesOut{end+1} = sprintf('ADC samples across all ring FIDs: %d', crtSet.nRings*cfg.nADCtotal);
        linesOut{end+1} = sprintf('Nucleus gamma/2pi: %.9g MHz/T', cfg.gammaBar_MHzT);
        linesOut{end+1} = 'Per-ring direct requirements:';
        for rr = 1:crtSet.nRings
            pv = previews{rr};
            maxG = max(abs(pv.G),[],1)*1e3;
            maxS = max(abs(pv.S),[],1);
            linesOut{end+1} = sprintf('- ring %d, r=%.6g: max|Gaxis|=[%s] mT/m; max|Saxis|=[%s] T/m/s', ...
                rr, crtSet.radii(rr), vecToStr(maxG), vecToStr(maxS)); %#ok<AGROW>
        end
        linesOut{end+1} = 'No ring-to-ring connectors are placed inside an ADC period.';
        linesOut{end+1} = 'After optimization, each ring receives independent real pre- and post-gradients.';
    end

    function setReportFromCrtRingSetResult(resultSet, cfg)
        s = resultSet.summary;
        linesOut = {};
        linesOut{end+1} = 'Optimized complete CRT ring set';
        linesOut{end+1} = sprintf('All feasible (readout + pre + post): %d', s.allFeasible);
        if isfield(s,'allFullFidReturnsFeasible')
            linesOut{end+1} = sprintf('All full-FID modules return to k=0: %d', ...
                s.allFullFidReturnsFeasible);
        end
        linesOut{end+1} = sprintf('Rings: %d', resultSet.nRings);
        linesOut{end+1} = sprintf('Npp per ring: %d', resultSet.NppPerRing);
        linesOut{end+1} = sprintf('Total spatial samples: %d', resultSet.totalSpatialSamples);
        linesOut{end+1} = sprintf('ADC samples across all ring FIDs: %d', resultSet.totalADCSamplesAllRings);
        linesOut{end+1} = sprintf('Period duration per ring: %.6g ms', cfg.periodTime*1e3);
        linesOut{end+1} = sprintf('Nspec per ring/FID: %d', cfg.Nspec);
        linesOut{end+1} = sprintf('Worst k RMS error: %.6g cycles/m', s.worstKErrorRMS);
        linesOut{end+1} = sprintf('Worst k max error: %.6g cycles/m', s.worstKErrorMax);
        linesOut{end+1} = sprintf('Max |G_axis| across rings: [%s] mT/m', vecToStr(s.maxGAxisAcrossRings*1e3));
        linesOut{end+1} = sprintf('Max |S_axis| across rings: [%s] T/m/s', vecToStr(s.maxSAxisAcrossRings));
        linesOut{end+1} = sprintf('Complete-module max |G_axis|: [%s] mT/m', vecToStr(s.maxGAxisCompleteModule*1e3));
        linesOut{end+1} = sprintf('Complete-module max |S_axis|: [%s] T/m/s', vecToStr(s.maxSAxisCompleteModule));
        linesOut{end+1} = sprintf('Worst complete-module return error: %.6g cycles/m', s.worstReturnError);
        if isfield(s,'worstFullFidReturnError')
            linesOut{end+1} = sprintf('Worst full-FID module return error: %.6g cycles/m', ...
                s.worstFullFidReturnError);
        end
        linesOut{end+1} = 'Per-ring summary:';
        for rr = 1:resultSet.nRings
            r = resultSet.rings(rr);
            prePass = true;
            if isfield(r,'pre') && isfield(r.pre,'isFeasible')
                prePass = logical(r.pre.isFeasible);
            end
            postPass = true;
            returnErr = 0;
            if isfield(r,'post') && isfield(r.post,'isFeasible')
                postPass = logical(r.post.isFeasible);
            end
            if isfield(r,'sequence') && isfield(r.sequence,'returnErrorNorm')
                returnErr = r.sequence.returnErrorNorm;
            end
            linesOut{end+1} = sprintf('- ring %d, r=%.6g: readout=%d, pre=%d, post=%d, return=%.3g c/m, RMS=%.4g, max=%.4g', ...
                rr,r.ringRadius,r.report.isFeasible,prePass,postPass, ...
                returnErr,r.report.kErrorRMS,r.report.kErrorMax); %#ok<AGROW>
        end
        setReport(linesOut);
    end

    function lines = reportFromTarget(ktraj, preview, cfg)
        closure = check_periodic_closure(ktraj, preview.G, struct('gammaBar',cfg.gammaBar_MHzT*1e6,'dtGrad',cfg.dtADC));
        lines = {};
        lines{end+1} = 'Target period generated';
        lines{end+1} = sprintf('Periodic MRSI: %d', cfg.periodicMrsi);
        lines{end+1} = sprintf('Npp points/period: %d', cfg.Npp);
        lines{end+1} = sprintf('Nspec periods/FID: %d', cfg.Nspec);
        lines{end+1} = sprintf('ADC total: %d = Npp*Nspec', cfg.nADCtotal);
        lines{end+1} = sprintf('ADC dwell: %.6g us', cfg.adcDwell_us);
        lines{end+1} = sprintf('Tperiod: %.6g ms', cfg.periodTime*1e3);
        lines{end+1} = sprintf('Derived spectral BW: %.6g Hz', cfg.derivedSpectralBW);
        lines{end+1} = sprintf('Spectral resolution: %.6g Hz', cfg.spectralResolution);
        lines{end+1} = sprintf('Full readout: %.6g ms', cfg.readoutTimeTotal*1e3);
        lines{end+1} = sprintf('Target samples shown: %d', size(ktraj,1));
        if strcmp(cfg.trajType, 'Concentric CRT 2D')
            lines{end+1} = sprintf('CRT mode: %s', cfg.crt.mode);
            lines{end+1} = sprintf('CRT rings: %d', cfg.crt.nRings);
            lines{end+1} = sprintf('CRT ring index: %d', cfg.crt.ringIndex);
            lines{end+1} = sprintf('CRT turns/ring: %.6g', cfg.crt.nTurnsPerRing);
            lines{end+1} = sprintf('CRT rMin: %.6g cycles/m', cfg.crt.rMin);
            lines{end+1} = sprintf('CRT transition fraction: %.6g', cfg.crt.transitionFraction);
            lines{end+1} = sprintf('CRT alternate direction: %d', cfg.crt.alternateDirection);
            if isfield(cfg.crt,'forceHardC0C1')
                lines{end+1} = sprintf('CRT hard C0/C1 equality: %d', cfg.crt.forceHardC0C1);
            end
            if strcmp(cfg.crt.mode,'multi_ring_period')
                lines{end+1} = 'CRT warning: multi_ring_period packs multiple rings into one spectral period and is usually infeasible.';
                lines{end+1} = 'Recommended: use single_ring and run/acquire different ringIndex values as separate encodes.';
            end
        end
        lines{end+1} = sprintf('last sample to first sample |kN-k1|: %.6g', closure.deltaKTargetNorm);
        lines{end+1} = sprintf('periodic moment closure |dk_next|: %.6g', closure.deltaKFromMomentNorm);
        lines{end+1} = sprintf('direct max |G_axis|: %s mT/m', vecToStr(max(abs(preview.G),[],1)*1e3));
        if ~isempty(preview.S)
            lines{end+1} = sprintf('direct max |S_axis|: %s T/m/s', vecToStr(max(abs(preview.S),[],1)));
        end
    end

    function setReportFromResult(result, cfg, full)
        r = result.report;
        lines = {};
        lines{end+1} = 'Optimized compact period';
        lines{end+1} = sprintf('Feasible: %d', r.isFeasible);
        lines{end+1} = sprintf('Npp points/period: %d', cfg.Npp);
        lines{end+1} = sprintf('Nspec periods/FID: %d', cfg.Nspec);
        lines{end+1} = sprintf('ADC total: %d', cfg.nADCtotal);
        lines{end+1} = sprintf('Derived spectral BW: %.6g Hz', cfg.derivedSpectralBW);
        lines{end+1} = sprintf('Spectral resolution: %.6g Hz', cfg.spectralResolution);
        lines{end+1} = sprintf('Period duration: %.6g ms', cfg.periodTime*1e3);
        lines{end+1} = sprintf('Full readout: %.6g ms', cfg.readoutTimeTotal*1e3);
        lines{end+1} = sprintf('Optimized duration: %.3f ms', r.duration*1e3);
        lines{end+1} = sprintf('max |G_axis|: %s mT/m', vecToStr(r.maxGAxis*1e3));
        lines{end+1} = sprintf('max |S_axis|: %s T/m/s', vecToStr(r.maxSAxis));
        lines{end+1} = sprintf('max |G_norm|: %.3f mT/m', r.maxGNorm*1e3);
        lines{end+1} = sprintf('max |S_norm|: %.3f T/m/s', r.maxSNorm);
        lines{end+1} = sprintf('k error RMS: %.6g cycles/m', r.kErrorRMS);
        lines{end+1} = sprintf('k error max: %.6g cycles/m', r.kErrorMax);
        if isfield(result,'opts')
            if isfield(result.opts,'forceGPeriodicEqual')
                lines{end+1} = sprintf('hard G(end)=G(1): %d', result.opts.forceGPeriodicEqual);
            end
            if isfield(result.opts,'forceSlewPeriodicEqual')
                lines{end+1} = sprintf('hard C1 boundary equality: %d', result.opts.forceSlewPeriodicEqual);
            end
        end
        if isfield(result,'periodic')
            c = result.periodic.closure;
            lines{end+1} = sprintf('actual periodic moment closure |dk_next|: %.6g', c.deltaKFromMomentNorm);
            lines{end+1} = sprintf('G boundary norm: %.6g T/m', c.GBoundaryNorm);
            lines{end+1} = sprintf('G periodic jump norm: %.6g T/m', c.GPeriodicJumpNorm);
            if isfield(c,'SlewPeriodicJumpNorm')
                lines{end+1} = sprintf('Slew periodic jump norm: %.6g T/m/s', c.SlewPeriodicJumpNorm);
            end
            if isfield(r,'cyclicGJumpNorm')
                lines{end+1} = sprintf('cyclic G continuity error: %.6g T/m', r.cyclicGJumpNorm);
            end
            if isfield(r,'cyclicSlewJumpNorm')
                lines{end+1} = sprintf('cyclic slew continuity error: %.6g T/m/s', r.cyclicSlewJumpNorm);
            end
        end
        if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'G')
            pinfo = result.pre;
            lines{end+1} = sprintf('Pre-gradient enabled: 1');
            lines{end+1} = sprintf('Pre-gradient samples: %d', pinfo.Npre);
            lines{end+1} = sprintf('Pre-gradient duration: %.6g ms', pinfo.duration*1e3);
            lines{end+1} = sprintf('Pre start |G|: %.6g mT/m', pinfo.startGNorm*1e3);
            lines{end+1} = sprintf('Pre end-to-readout |dG|: %.6g mT/m', pinfo.endMismatchNorm*1e3);
            lines{end+1} = sprintf('Pre moment error: %.6g cycles/m', pinfo.momentErrorNorm);
            lines{end+1} = sprintf('Pre max |G_axis|: %s mT/m', vecToStr(pinfo.maxGAxis*1e3));
            lines{end+1} = sprintf('Pre max |S_axis|: %s T/m/s', vecToStr(pinfo.maxSAxis));
            lines{end+1} = sprintf('Pre feasible: %d', pinfo.isFeasible);
        end
        if isfield(result,'post') && isstruct(result.post) && isfield(result.post,'G')
            pinfo = result.post;
            lines{end+1} = 'Post-gradient enabled: 1';
            lines{end+1} = sprintf('Post-gradient samples: %d',pinfo.Npost);
            lines{end+1} = sprintf('Post-gradient duration: %.6g ms',pinfo.duration*1e3);
            lines{end+1} = sprintf('Post return error: %.6g cycles/m',pinfo.returnErrorNorm);
            lines{end+1} = sprintf('Post max |G_axis|: %s mT/m',vecToStr(pinfo.maxGAxis*1e3));
            lines{end+1} = sprintf('Post max |S_axis|: %s T/m/s',vecToStr(pinfo.maxSAxis));
            lines{end+1} = sprintf('Post feasible: %d',pinfo.isFeasible);
        end
        if isfield(result,'sequence') && isfield(result.sequence,'maxGAxis')
            lines{end+1} = sprintf('Complete-module max |G_axis|: %s mT/m', ...
                vecToStr(result.sequence.maxGAxis*1e3));
            lines{end+1} = sprintf('Complete-module max |S_axis|: %s T/m/s', ...
                vecToStr(result.sequence.maxSAxis));
            lines{end+1} = sprintf('Complete-module feasible: %d', ...
                result.sequence.isFeasible);
        end
        if ~isempty(full)
            lines{end+1} = sprintf('Full repeated gradient samples: %d', full.NtotalGrad);
        end
        if strcmp(cfg.trajType, 'Concentric CRT 2D')
            lines{end+1} = sprintf('CRT mode: %s', cfg.crt.mode);
            lines{end+1} = sprintf('CRT rings: %d', cfg.crt.nRings);
            lines{end+1} = sprintf('CRT turns/ring: %.6g', cfg.crt.nTurnsPerRing);
            lines{end+1} = sprintf('CRT transition fraction: %.6g', cfg.crt.transitionFraction);
            if isfield(cfg.crt,'usePreGradient')
                lines{end+1} = sprintf('CRT zero-start pre-gradient: %d', cfg.crt.usePreGradient);
                lines{end+1} = sprintf('CRT pre-gradient samples: %d (0=auto)', cfg.crt.preGradientSamples);
            end
            if isfield(cfg.crt,'usePostGradient')
                lines{end+1} = sprintf('CRT return-to-origin post-gradient: %d',cfg.crt.usePostGradient);
                lines{end+1} = sprintf('CRT post-gradient samples: %d (0=auto)',cfg.crt.postGradientSamples);
            end
            if strcmp(cfg.crt.mode,'multi_ring_period')
                lines{end+1} = 'CRT warning: multi_ring_period is a stress test, not the recommended MRSI CRT unit.';
            end
        end
        if ~isempty(r.warnings)
            lines{end+1} = 'Warnings:';
            for i = 1:numel(r.warnings)
                lines{end+1} = ['- ' r.warnings{i}]; %#ok<AGROW>
            end
        end
        setReport(lines);
    end

    function setReport(lines)
        handles = guidata(fig);
        if ischar(lines)
            lines = {lines};
        end
        set(handles.reportBox, 'String', lines);
    end

    function setStatus(txt)
        handles = guidata(fig);
        set(handles.statusText, 'String', txt);
        drawnow;
    end

    function showError(ME)
        setStatus(['Error: ' ME.message]);
        setReport({ME.message});
        errordlg(ME.message, 'NC-MRSI-GradOpt GUI error');
    end
end

function value = getPopupValue(h)
values = get(h, 'String');
value = values{get(h, 'Value')};
end

function x = readDouble(h, name)
x = str2double(get(h, 'String'));
if ~isfinite(x)
    error('%s must be numeric.', name);
end
end

function x = readPositiveDouble(h, name)
x = readDouble(h, name);
if x <= 0
    error('%s must be positive.', name);
end
end

function x = readNonnegativeDouble(h, name)
x = readDouble(h, name);
if x < 0
    error('%s must be nonnegative.', name);
end
end

function x = readPositiveInteger(h, name)
x = round(readPositiveDouble(h, name));
if x < 1
    error('%s must be a positive integer.', name);
end
set(h, 'String', num2str(x));
end

function labels = axisLabels(D, prefix)
base = {'x','y','z'};
labels = cell(1,D);
for i = 1:D
    if i <= numel(base)
        labels{i} = [prefix base{i}];
    else
        labels{i} = sprintf('%s%d', prefix, i);
    end
end
end

function s = vecToStr(v)
s = sprintf('%.3f ', v);
s = strtrim(s);
end

function data = readmatrix_compat(filePath)
if exist('readmatrix','file') == 2
    data = readmatrix(filePath);
else
    try
        data = dlmread(filePath, ',');
    catch
        data = dlmread(filePath);
    end
end
data = data(all(isfinite(data),2), :);
end

function yline_compat(ax, y, style)
if exist('yline','file') == 2
    yline(ax, y, style);
else
    xl = get(ax, 'XLim');
    plot(ax, xl, [y y], style);
end
end

function xline_compat(ax, x, style)
if exist('xline','file') == 2
    xline(ax, x, style);
else
    yl = get(ax, 'YLim');
    plot(ax, [x x], yl, style);
end
end

function G = gradientFromK(ktraj, dt, gammaBar)
% Finite-difference gradient preview from target k. The first point is set to
% zero so that the preview is a diagnostic, not a constrained optimum.
G = zeros(size(ktraj));
if size(ktraj,1) < 2
    return;
end
G(2:end,:) = diff(ktraj,1,1) ./ (gammaBar * dt);
end


function G = periodicGradientFromK(ktraj, dt, gammaBar)
%PERIODICGRADIENTFROMK Cyclic finite-difference preview for one period.
% G(i) maps k(i) to k(i+1), with k(N+1)=k(1).
N = size(ktraj,1);
D = size(ktraj,2);
G = zeros(N,D);
if N < 2
    return;
end
G(1:N-1,:) = diff(ktraj,1,1) ./ (gammaBar * dt);
G(N,:) = (ktraj(1,:) - ktraj(N,:)) ./ (gammaBar * dt);
end

function k = kFromGradient(G, dt, gammaBar, k0)
if nargin < 4 || isempty(k0)
    k0 = zeros(1,size(G,2));
end
k = repmat(k0, [size(G,1), 1]) + gammaBar * dt * cumsum(G,1);
end

function showKErrorPopup(ktarget, kactual, timeVec)
D = size(ktarget,2);
if isempty(timeVec)
    x = (1:size(ktarget,1)).';
    xlab = 'sample';
else
    x = timeVec(:) * 1e3;
    xlab = 'time (ms)';
end
n = min(size(ktarget,1), size(kactual,1));
ktarget = ktarget(1:n,:);
kactual = kactual(1:n,:);
x = x(1:n);
e = kactual - ktarget;
en = sqrt(sum(e.^2,2));
fig2 = figure('Name','K target vs actual / periodic error', 'NumberTitle','off', ...
    'Units','normalized', 'Position',[0.12 0.12 0.76 0.72]);
ax1 = subplot(2,2,1,'Parent',fig2); hold(ax1,'on');
base = {'kx','ky','kz'};
for d = 1:D
    plot(ax1, x, ktarget(:,d), '--', 'LineWidth',1.0);
end
for d = 1:D
    plot(ax1, x, kactual(:,d), '-', 'LineWidth',1.1);
end
grid(ax1,'on'); xlabel(ax1,xlab); ylabel(ax1,'k (cycles/m)'); title(ax1,'target vs actual k components');
legend(ax1, makeLegend(D, 'target', 'actual'), 'Location','best');

ax2 = subplot(2,2,2,'Parent',fig2); hold(ax2,'on');
for d = 1:D
    plot(ax2, x, e(:,d), 'LineWidth',1.1);
end
grid(ax2,'on'); xlabel(ax2,xlab); ylabel(ax2,'dk (cycles/m)'); title(ax2,'component error');
legend(ax2, base(1:D), 'Location','best');

ax3 = subplot(2,2,3,'Parent',fig2);
plot(ax3, x, en, 'LineWidth',1.1); grid(ax3,'on'); xlabel(ax3,xlab); ylabel(ax3,'|dk|');
title(ax3, sprintf('|dk| RMS=%.4g, max=%.4g, end=%.4g', rms_compat(en), max(en), en(end)));

ax4 = subplot(2,2,4,'Parent',fig2);
if D >= 3
    plot3(ax4, ktarget(:,1), ktarget(:,2), ktarget(:,3), '--', kactual(:,1), kactual(:,2), kactual(:,3), '-');
    xlabel(ax4,'kx'); ylabel(ax4,'ky'); zlabel(ax4,'kz'); view(ax4,3);
else
    plot(ax4, ktarget(:,1), ktarget(:,2), '--', kactual(:,1), kactual(:,2), '-');
    xlabel(ax4,'kx'); ylabel(ax4,'ky');
end
grid(ax4,'on'); axis(ax4,'equal'); title(ax4,'trajectory geometry'); legend(ax4,{'target','actual'},'Location','best');
end

function labels = makeLegend(D, a, b)
base = {'kx','ky','kz'};
labels = {};
for d = 1:D
    labels{end+1} = [base{d} ' ' a]; %#ok<AGROW>
end
for d = 1:D
    labels{end+1} = [base{d} ' ' b]; %#ok<AGROW>
end
end

function r = rms_compat(x)
r = sqrt(mean(x(:).^2));
end



function crt = ensureCrtDefaults(crt)
%ENSURECRTDEFAULTS Add fields introduced in newer GUI versions.
def = defaultCrtParams();
fields = fieldnames(def);
if ~isstruct(crt) || isempty(crt)
    crt = def;
    return;
end
for ii = 1:numel(fields)
    f = fields{ii};
    if ~isfield(crt,f) || isempty(crt.(f))
        crt.(f) = def.(f);
    end
end
end
function crt = defaultCrtParams()
%DEFAULTCRTPARAMS Default settings for Concentric CRT 2D GUI dialog.
crt = struct();
crt.mode = 'multi_ring_set';            % complete set: every ring is an independent Npp-sample period
crt.useFovResolution = true;           % Derive Kmax and nRings from FOV/resolution
crt.fov_mm = 240;                      % Field of view used to estimate dk=1/FOV
crt.resolution_mm = 20;                % Nominal resolution used to estimate Kmax=1/(2*dx)
crt.nRings = 6;                        % Number of independently optimized concentric rings
crt.ringIndex = 6;                     % Selected ring for single_ring mode; default outer ring
crt.nTurnsPerRing = 1;                 % Angular turns per ring
crt.rMin = 1/0.240;                    % Inner radius = 1/FOV, cycles/m
crt.transitionFraction = 0.25;         % Fraction used for radial connectors in multi_ring_period only
crt.alternateDirection = false;        % Reverse angular direction on alternating rings
crt.usePreGradient = true;             % Add non-ADC pre-gradient before CRT ring; starts at G=0
crt.preGradientSamples = 0;            % 0=auto; otherwise fixed number of pre-gradient samples
crt.usePostGradient = true;            % Add real non-ADC post-gradient returning to k=0 and G=0
crt.postGradientSamples = 0;           % 0=auto; otherwise fixed number of post-gradient samples
crt.forceHardC0C1 = false;             % Default target-fidelity mode for CRT: cyclic slew only, no hard G(end)=G(1)/C1 equality
end

function x = readDialogPositive(h, name)
x = str2double(get(h,'String'));
if ~isfinite(x) || x <= 0
    error('%s must be a positive number.', name);
end
end

function x = readDialogNonnegative(h, name)
x = str2double(get(h,'String'));
if ~isfinite(x) || x < 0
    error('%s must be a nonnegative number.', name);
end
end

function txt = crtSummaryString(crt)
crt = ensureCrtDefaults(crt);
if crt.useFovResolution
    txt = sprintf('CRT settings: %s, FOV %.3g mm, resolution %.3g mm -> rings %d, ringIndex %d, rMin %.4g cycles/m, real pre/post %d/%d, hard C0/C1 %d.', ...
        crt.mode,crt.fov_mm,crt.resolution_mm,crt.nRings,crt.ringIndex, ...
        crt.rMin,crt.usePreGradient,crt.usePostGradient,crt.forceHardC0C1);
else
    txt = sprintf('CRT settings: %s, rings %d, ringIndex %d, turns/ring %.3g, rMin %.4g, transition %.3g, real pre/post %d/%d, hard C0/C1 %d.', ...
        crt.mode,crt.nRings,crt.ringIndex,crt.nTurnsPerRing,crt.rMin, ...
        crt.transitionFraction,crt.usePreGradient,crt.usePostGradient, ...
        crt.forceHardC0C1);
end
end

function tf = isCrtRingSetConfig(cfg)
tf = isstruct(cfg) && isfield(cfg,'trajType') && ...
    strcmp(cfg.trajType,'Concentric CRT 2D') && ...
    isfield(cfg,'crt') && isfield(cfg.crt,'mode') && ...
    strcmp(cfg.crt.mode,'multi_ring_set');
end

function tf = isCrtRingSetResult(result)
tf = isstruct(result) && isfield(result,'isCrtRingSet') && ...
    logical(result.isCrtRingSet);
end
