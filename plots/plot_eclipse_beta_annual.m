function fig = plot_eclipse_beta_annual(ecl_res, cfg, const, out_png)
% PLOT_ECLIPSE_BETA_ANNUAL 365-day Solar Beta Angle & Eclipse Duration Envelope.
% Explicitly annotates Worst Cold Case (max eclipse at beta=0) and Worst Hot Case
% (min eclipse / full sun at |beta|_max) for Power & Simscape Thermal subsystems!

    fig = figure('Name', sprintf('Annual Beta & Eclipse - %s', cfg.code), ...
                 'Units', 'pixels', 'Position', [100, 100, 1050, 620], 'Visible', 'off', 'Color', 'w');

    %% Panel 1: 365-Day Solar Beta Angle Evolution
    subplot(2, 1, 1);
    plot(ecl_res.days_yr, ecl_res.beta_yr_deg, 'Color', const.colors.TUMBlue, 'LineWidth', 1.8, ...
         'DisplayName', sprintf('\\beta(t) Evolution (d\\Omega/dt = %.2f^\\circ/day)', ecl_res.raan_dot_deg_day));
    hold on; grid on; box on;
    yline(0, 'k--', 'LineWidth', 0.9, 'HandleVisibility', 'off');
    yline( ecl_res.beta_crit_deg, ':', 'Color', const.colors.TUMOrange, 'LineWidth', 1.6, ...
          'DisplayName', sprintf('Full-Sunlight Limit (\\pm\\beta_{crit} = \\pm%.1f^\\circ)', ecl_res.beta_crit_deg));
    yline(-ecl_res.beta_crit_deg, ':', 'Color', const.colors.TUMOrange, 'LineWidth', 1.6, 'HandleVisibility', 'off');

    xlim([0, 365]);
    ylim([-90, 90]);
    yticks(-90:30:90);
    ylabel('Solar Beta Angle \beta [deg]', 'FontSize', 10, 'FontWeight', 'bold');
    title(sprintf('%s — 1-Year Solar Beta Angle & Power/Thermal Eclipse Envelope (%d km, %.1f^\\circ)', ...
          cfg.name, round(cfg.h_km), cfg.inc_deg), 'FontSize', 11.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'northeast', 'FontSize', 8.5);

    %% Panel 2: Orbital Eclipse Duration per Revolution [min] (Worst Cold & Worst Hot Cases)
    subplot(2, 1, 2);
    area(ecl_res.days_yr, ecl_res.ecl_dur_yr_min, 'FaceColor', const.colors.TUMLight, ...
         'EdgeColor', const.colors.TUMDark, 'LineWidth', 1.4, 'FaceAlpha', 0.55, ...
         'DisplayName', 'Eclipse Duration per Orbit [min]');
    hold on; grid on; box on;

    [max_e, i_max] = max(ecl_res.ecl_dur_yr_min);
    [min_e, i_min] = min(ecl_res.ecl_dur_yr_min);

    plot(ecl_res.days_yr(i_max), max_e, 'o', 'MarkerFaceColor', const.colors.TUMRed, ...
         'MarkerEdgeColor', 'k', 'MarkerSize', 7.5, ...
         'DisplayName', sprintf('Worst Cold Case: t_{ecl,max} = %.2f min (%.1f%% of orbit)', ...
         max_e, 100*max_e/ecl_res.T_orbit_min));
    plot(ecl_res.days_yr(i_min), min_e, 's', 'MarkerFaceColor', const.colors.TUMOrange, ...
         'MarkerEdgeColor', 'k', 'MarkerSize', 7.5, ...
         'DisplayName', sprintf('Worst Hot Case: t_{ecl,min} = %.2f min (Full-Sun days: %.0f d/yr)', ...
         min_e, ecl_res.full_sun_days_per_yr));

    xlim([0, 365]);
    ylim([0, max(42.0, max_e * 1.25)]);
    xlabel('Mission Elapsed Time [days from 01-Jun-2028 Epoch]', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Eclipse Duration [min / orbit]', 'FontSize', 10, 'FontWeight', 'bold');
    legend('Location', 'southoutside', 'NumColumns', 2, 'FontSize', 8.5);

    if nargin >= 4 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end
