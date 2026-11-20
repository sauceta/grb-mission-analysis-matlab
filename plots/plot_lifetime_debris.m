function fig = plot_lifetime_debris(results, req, const, out_png)
% PLOT_LIFETIME_DEBRIS Bounded NRLMSISE-00 Orbit Lifetime & ECSS Delta-V Budget Breakdown.
% Directly verifies ESA ESSB-ST-U-007 5-year post-mission disposal compliance (LIF-010, LIF-030)
% across Solar Min / Nominal / Solar Max bounding regimes!

    fig = figure('Name', 'Orbit Lifetime & Delta-V Budget', ...
                 'Units', 'pixels', 'Position', [80, 60, 1260, 560], 'Visible', 'off', 'Color', 'w');

    %% Panel 1: NRLMSISE-00 Solar Min / Nominal / Solar Max Lifetime Envelope (SmallSat B_ref)
    subplot(1, 2, 1);
    l1 = results(1).life; % Reference SmallSat ballistic coefficient
    alt = l1.alt_grid_km;

    % Shaded Solar Min to Solar Max uncertainty band
    fill([alt, fliplr(alt)], [max(l1.curve_max_yr, 0.02), fliplr(max(l1.curve_min_yr, 0.02))], ...
         const.colors.TUMLight, 'FaceAlpha', 0.45, 'EdgeColor', 'none', ...
         'DisplayName', 'NRLMSISE-00 Solar Max–Min Envelope (F_{10.7}=70–220)');
    hold on; grid on; box on;

    semilogy(alt, l1.curve_min_yr, '--', 'Color', const.colors.TUMRed, 'LineWidth', 1.8, ...
             'DisplayName', 'Solar Minimum (F_{10.7}=70 — Worst-Case Slow Decay)');
    semilogy(alt, l1.curve_nom_yr, '-',  'Color', const.colors.TUMBlue, 'LineWidth', 2.2, ...
             'DisplayName', 'Solar Nominal (F_{10.7}=140)');
    semilogy(alt, l1.curve_max_yr, '-.', 'Color', const.colors.TUMGreen, 'LineWidth', 1.6, ...
             'DisplayName', 'Solar Maximum (F_{10.7}=220 — Worst-Case High Drag)');
    set(gca, 'YScale', 'log');

    yline(req.LIF_010_max_post_mission_yr, 'r-', 'LineWidth', 2.2, ...
          'DisplayName', 'ESA ESSB-ST-U-007 5-Year Rule Limit');
    yline(25.0, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Obsolete 25-Year Rule');

    % Overlay each architecture's actual natural Solar-Min lifetime (own B_drag!)
    dx_l = [ -34,  -36,    6,    6,    6,  -34];
    dy_l = [1.22, 0.72, 1.25, 0.72, 0.70, 0.68];
    for i = 1:length(results)
        plot(results(i).h_km, results(i).life.life_solar_min_yr, 'o', ...
             'MarkerFaceColor', const.colors.TUMOrange, 'MarkerEdgeColor', 'k', 'MarkerSize', 7, ...
             'HandleVisibility', 'off');
        text(results(i).h_km + dx_l(i), results(i).life.life_solar_min_yr * dy_l(i), results(i).code, ...
             'FontSize', 7.8, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy, ...
             'BackgroundColor', [1 1 1 0.72], 'Margin', 1);
    end

    xlim([350, 650]); ylim([0.05, 220]);
    xlabel('Initial Circular Orbit Altitude [km]', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Unassisted Natural Orbital Lifetime [years] (log)', 'FontSize', 10, 'FontWeight', 'bold');
    title('1. Bounded Natural Lifetime vs ESA 5-Year Debris Limit', 'FontSize', 11, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'southeast', 'FontSize', 7.4);

    %% Panel 2: Stacked ECSS-E-ST-32-10C Delta-V Budget Breakdown Across Architectures
    subplot(1, 2, 2);
    N = length(results);
    dv_mat = zeros(N, 6);
    for i = 1:N
        lf = results(i).life;
        dv_mat(i, :) = [lf.dv_injection_ms, lf.dv_phasing_ms, lf.dv_drag_max_ms, ...
                        lf.dv_cam_ms, lf.dv_disposal_ms, lf.dv_margin_ms];
    end

    b = bar(1:N, dv_mat, 'stacked');
    bar_cols = [const.colors.TUMDark; const.colors.TUMPurple; const.colors.TUMOrange; ...
                const.colors.TUMGreen; const.colors.TUMRed; const.colors.TUMGray];
    bar_lbls = {'Injection Trim', 'Constell. Phasing', 'Solar-Max Drag Makeup', ...
                'Collision Avoidance (CAM)', 'EOL Disposal (ESSB-ST-U-007)', 'ECSS +10% Margin'};
    for c = 1:6
        b(c).FaceColor = bar_cols(c, :);
        b(c).DisplayName = bar_lbls{c};
    end
    hold on; grid on; box on;

    totals = sum(dv_mat, 2);
    for i = 1:N
        text(i, totals(i) + 6, sprintf('%.0f m/s\n(%.1f kg)', totals(i), results(i).life.prop_per_sat_kg), ...
             'HorizontalAlignment', 'center', 'FontSize', 7.6, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    end

    set(gca, 'XTick', 1:N, 'XTickLabel', {results.short_name}, 'XTickLabelRotation', 20, 'FontSize', 8.5);
    ylabel('Required Mission \Deltav per Satellite [m/s]', 'FontSize', 10, 'FontWeight', 'bold');
    ylim([0, max(totals) * 1.25 + 15]);
    title('2. Sized Mission \Deltav Budget & Propellant Mass per Satellite', 'FontSize', 11, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'northwest', 'FontSize', 7.8);

    sgtitle('GRB Alert Mission — ESA ESSB-ST-U-007 Space Debris Compliance & Propulsion Sizing', ...
            'FontSize', 13, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);

    if nargin >= 4 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end
