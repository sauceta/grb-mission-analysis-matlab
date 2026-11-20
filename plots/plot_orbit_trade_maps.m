function fig = plot_orbit_trade_maps(trade_orb, results, const, out_png)
% PLOT_ORBIT_TRADE_MAPS Publication-grade 2x2 Altitude x Inclination Orbit Trade Space Maps.
% Directly visualizes the coupled orbital design trades for the Mission Analysis chapter:
%   Panel 1: IGRF-14 Radiation-Free Duty Cycle [%] (SAA + Polar Horns)
%   Panel 2: Equatorial VHF Alert Network Coverage [%] (OPS-020 >= 90%)
%   Panel 3: Passive Orbital Lifetime at Solar Minimum [years] (ESA 5-yr ESSB-ST-U-007)
%   Panel 4: Solar-Max 3-Year Drag Makeup Delta-V [m/s] & Feasible Design Corridor!
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    fig = figure('Name', 'Orbit Selection Trade Space', ...
                 'Units', 'pixels', 'Position', [60, 40, 1280, 820], 'Visible', 'off', 'Color', 'w');

    [H, I] = meshgrid(trade_orb.h_grid_km, trade_orb.inc_grid_deg);

    % Helper to overlay candidate architecture markers
    arch_h   = [results.h_km];
    arch_inc = [results.inc_deg];
    arch_lbl = {results.code};

    %% Panel 1: Radiation-Free Duty Cycle (IGRF-14 SAA + Polar Horns)
    subplot(2, 2, 1);
    contourf(H, I, trade_orb.rad_duty_pct, 16, 'LineColor', 'none');
    hold on;
    [C1, h1] = contour(H, I, trade_orb.rad_duty_pct, [60, 75, 85, 90, 95], 'k-', 'LineWidth', 1.0);
    clabel(C1, h1, 'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k');
    yline(30.0, '--', 'Color', const.colors.TUMRed, 'LineWidth', 1.8);
    text(406, 35.0, 'ENV-050 Limit (i \leq 30^{\circ})', 'Color', const.colors.TUMRed, ...
         'FontWeight', 'bold', 'FontSize', 8.5, 'BackgroundColor', [1 1 1 0.78], 'Margin', 1);
    overlay_archs(arch_h, arch_inc, arch_lbl);
    cb1 = colorbar; cb1.Label.String = 'Radiation-Free Duty Cycle [%]';
    colormap(gca, parula);
    clim([50, 100]); ylim([0, 104]);
    xlabel('Circular Orbit Altitude [km]', 'FontWeight', 'bold');
    ylabel('Orbit Inclination [deg]', 'FontWeight', 'bold');
    title('1. IGRF-14 Radiation Duty Cycle (SAA + Polar Horns)', 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    grid on; box on;

    %% Panel 2: Equatorial VHF Alert Network Coverage (OPS-020 >= 90%)
    subplot(2, 2, 2);
    contourf(H, I, trade_orb.vhf_cov_pct, 16, 'LineColor', 'none');
    hold on;
    [C2, h2] = contour(H, I, trade_orb.vhf_cov_pct, [40, 60, 80, 90, 95], 'k-', 'LineWidth', 1.0);
    clabel(C2, h2, 'FontSize', 8, 'FontWeight', 'bold');
    contour(H, I, trade_orb.vhf_cov_pct, [90, 90], 'r-', 'LineWidth', 2.0);
    yline(30.0, '--', 'Color', const.colors.TUMRed, 'LineWidth', 1.8);
    overlay_archs(arch_h, arch_inc, arch_lbl);
    cb2 = colorbar; cb2.Label.String = 'VHF Network Coverage [%]';
    colormap(gca, parula);
    clim([30, 100]); ylim([0, 104]);
    xlabel('Circular Orbit Altitude [km]', 'FontWeight', 'bold');
    ylabel('Orbit Inclination [deg]', 'FontWeight', 'bold');
    title('2. Equatorial VHF Alert Reception Coverage (OPS-020 \geq 90%)', 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    grid on; box on;

    %% Panel 3: Passive Orbital Lifetime at Solar Minimum (ESA ESSB-ST-U-007)
    subplot(2, 2, 3);
    log_life = log10(max(trade_orb.life_smin_yr, 0.1));
    contourf(H, I, log_life, 18, 'LineColor', 'none');
    hold on;
    [C3, h3] = contour(H, I, trade_orb.life_smin_yr, [1, 2, 5, 10, 25, 100], 'k-', 'LineWidth', 1.1);
    clabel(C3, h3, 'FontSize', 8, 'FontWeight', 'bold');
    contour(H, I, trade_orb.life_smin_yr, [5.0, 5.0], 'r-', 'LineWidth', 2.4);
    text(452, 72, 'ESA 5-Yr Passive Limit', 'Color', 'r', 'FontWeight', 'bold', 'FontSize', 8.5, 'BackgroundColor', 'w', 'EdgeColor', 'r');
    overlay_archs(arch_h, arch_inc, arch_lbl);
    cb3 = colorbar; cb3.Label.String = 'log_{10}(Solar-Min Lifetime [yr])';
    colormap(gca, flipud(parula));
    clim([0, 2.2]); ylim([0, 104]);
    xlabel('Circular Orbit Altitude [km]', 'FontWeight', 'bold');
    ylabel('Orbit Inclination [deg]', 'FontWeight', 'bold');
    title('3. Passive Orbit Lifetime at Solar Min (NRLMSISE-00, B=0.019 m^2/kg)', 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    grid on; box on;

    %% Panel 4: Solar-Max 3-Year Drag Makeup Delta-V & Feasible Design Corridor
    subplot(2, 2, 4);
    contourf(H, I, min(trade_orb.dv_drag3yr_ms, 120.0), 16, 'LineColor', 'none');
    hold on;
    [C4, h4] = contour(H, I, trade_orb.dv_drag3yr_ms, [5, 15, 30, 50, 80], 'k-', 'LineWidth', 1.0);
    clabel(C4, h4, 'FontSize', 8, 'FontWeight', 'bold');
    contour(H, I, double(trade_orb.feasible_mask), [0.5, 0.5], 'g-', 'LineWidth', 2.8);
    text(538, 10, 'FEASIBLE CORRIDOR', 'Color', [0.05, 0.45, 0.05], ...
         'FontWeight', 'bold', 'FontSize', 8.2, 'BackgroundColor', [0.92, 1.0, 0.92], 'EdgeColor', [0.1, 0.6, 0.1]);
    overlay_archs(arch_h, arch_inc, arch_lbl);
    cb4 = colorbar; cb4.Label.String = '3-Yr Solar-Max Drag \Deltav [m/s]';
    colormap(gca, flipud(hot));
    clim([0, 120]); ylim([0, 104]);
    xlabel('Circular Orbit Altitude [km]', 'FontWeight', 'bold');
    ylabel('Orbit Inclination [deg]', 'FontWeight', 'bold');
    title('4. Solar-Max 3-Yr Drag \Deltav & Feasible LEO Corridor', 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    grid on; box on;

    sgtitle('GRB Alert Mission — Parametric Orbit Selection Trade Space (Altitude \times Inclination)', ...
            'FontSize', 14, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);

    if nargin >= 4 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end

function overlay_archs(hs, incs, lbls)
    % Clean non-overlapping offsets for all 6 architectures
    dx_list = [-32,   5,   4,   5,   5,   6];
    dy_list = [ -8,   5,   6,   6,  -8,  -8];
    for k = 1:length(hs)
        plot(hs(k), incs(k), 'o', 'MarkerFaceColor', [0.0, 0.396, 0.741], 'MarkerEdgeColor', 'w', 'MarkerSize', 7.0, 'LineWidth', 1.2);
        text(hs(k) + dx_list(k), incs(k) + dy_list(k), lbls{k}, 'Color', 'k', 'FontSize', 7.2, ...
             'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.80], 'Margin', 1);
    end
end
