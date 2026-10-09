function make_demo_figures(outputDir)
%MAKE_DEMO_FIGURES Deterministic trajectory reference figures (not TBME manuscript figures).
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir);
startup_nc_mrsi_gradopt;
if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(rootDir,'reproducibility','outputs','demo');
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
rng(20261009,'twister');
Npp = 128; Kmax = 25;
variants = {'petalute_paper','legacy_sin2'};
for ii = 1:numel(variants)
    variant = variants{ii};
    p = struct('Npp',Npp,'Kmax',Kmax,'shape',variant,'phi',pi/6, ...
        'beta',0,'nRadial',1,'nAngular',1);
    k2 = make_periodic_rosette_2d(p);
    k3 = make_periodic_rosette_3d(p);
    assert(isequal(size(k2),[Npp,2]) && isequal(size(k3),[Npp,3]));
    assert(all(isfinite(k2(:))) && all(isfinite(k3(:))));
    save(fullfile(outputDir,['trajectory_' variant '.mat']), ...
        'p','k2','k3','Npp','Kmax','variant');
    writematrix(k2,fullfile(outputDir,['trajectory_2d_' variant '.csv']));
    writematrix(k3,fullfile(outputDir,['trajectory_3d_' variant '.csv']));
    f = figure('Visible','off','Color','w','Position',[100 100 850 360]);
    subplot(1,2,1); plot(k2(:,1),k2(:,2),'LineWidth',1.5); axis equal; grid on;
    xlabel('k_x (cycles/m)'); ylabel('k_y (cycles/m)'); title(['2D ' variant],'Interpreter','none');
    subplot(1,2,2); plot3(k3(:,1),k3(:,2),k3(:,3),'LineWidth',1.5);
    axis equal; grid on; view(36,22);
    xlabel('k_x (cycles/m)'); ylabel('k_y (cycles/m)'); zlabel('k_z (cycles/m)');
    title(['3D ' variant],'Interpreter','none');
    exportgraphics(f,fullfile(outputDir,['demo_' variant '.png']),'Resolution',300);
    try
        exportgraphics(f,fullfile(outputDir,['demo_' variant '.svg']),'ContentType','vector');
    catch ME
        warning('SVG export unavailable: %s',ME.message);
    end
    close(f);
end
fprintf('Demo figures generated in %s\n',outputDir);
end
