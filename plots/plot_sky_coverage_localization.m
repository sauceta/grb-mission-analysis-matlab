function fig = plot_sky_coverage_localization(results, req, const, out_png)
% PLOT_SKY_COVERAGE_LOCALIZATION Compares physics-based localization r90 CDF & annual GRB yield.
% Directly visualizes MIS-020 (>= 40 GRBs/yr) and MIS-030 / PER-010 (r90 <= 10 arcmin).

    fig = figure('Name', 'GRB Localization Error & Annual Yield', ...
                 'Units', 'pixels', 'Position', [80, 60, 1260, 560], 'Visible', 'off', 'Color', 'w');

    N = length(results);
    cols = {const.colors.TUMBlue, const.colors.TUMNavy, const.colors.TUMOrange, ...
            const.colors.TUMGreen, const.colors.TUMPurple, const.colors.TUMGray};
    styles = {'-', '--', '-', '-.', ':', '--'};

    %% Panel 1: Cumulative Distribution Function of 90% Localization Error Radius r90 [arcmin]
    subplot(1, 2, 1);
    hold on; grid on; box on;
    for i = 1:N
        r90s = sort(results(i).r90_samples_arcmin);
        if isempty(r90s), continue; end
        p_cdf = (1:length(r90s)) / length(r90s) * 100.0;
        semilogx(r90s, p_cdf, 'Color', cols{i}, 'LineStyle', styles{i}, 'LineWidth', 2.2, ...
                 'DisplayName', sprintf('%s: %s (med %.1f'')', results(i).code, results(i).short_name, results(i).r90_median_arcmin));
    end
    set(gca, 'XScale', 'log');
    xline(req.MIS_030_goal_arcmin, ':', 'Color', const.colors.TUMGreen, 'LineWidth', 1.6, ...
          'DisplayName', 'MIS-030 Goal (3'')');
    xline(req.MIS_030_loc_r90_arcmin, '--', 'Color', const.colors.TUMRed, 'LineWidth', 2.0, ...
          'DisplayName', 'MIS-030 Threshold (10'')');
    xline(23.6, '-.', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.4, ...
          'DisplayName', 'Swift XRT Single FoV (23.6'')');

    xlim([1.0, 500.0]); ylim([0, 102]);
    xlabel('On-Board 90% Localization Error Radius r_{90} [arcmin] (log scale)', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Cumulative Fraction of Detected Bursts [%]', 'FontSize', 10, 'FontWeight', 'bold');
    title('1. Monte Carlo Localization Accuracy CDF (3,000 GRBs)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'southeast', 'FontSize', 7.8);

    %% Panel 2: Annual Detected vs Usefully Localized GRBs/Year (r90 <= 10')
    subplot(1, 2, 2);
    det_yr = [results.annual_detected_bursts];
    loc_yr = [results.annual_localized_10am];
    codes  = {results.short_name};

    b = bar(1:N, [det_yr; loc_yr]', 'grouped');
    b(1).FaceColor = const.colors.TUMLight;
    b(1).EdgeColor = const.colors.TUMDark;
    b(1).DisplayName = 'Total Detected GRBs/yr (SNR \geq 6.5)';
    b(2).FaceColor = const.colors.TUMBlue;
    b(2).EdgeColor = const.colors.TUMNavy;
    b(2).DisplayName = 'Usefully Localized (r_{90} \leq 10'') [MOE]';

    hold on; grid on; box on;
    yline(req.MIS_020_min_bursts_per_yr, '--', 'Color', const.colors.TUMRed, 'LineWidth', 2.0, ...
          'DisplayName', sprintf('MIS-020 Threshold (%d bursts/yr)', round(req.MIS_020_min_bursts_per_yr)));

    for i = 1:N
        text(i + 0.16, loc_yr(i) + 4, sprintf('%.0f', loc_yr(i)), ...
             'HorizontalAlignment', 'center', 'FontSize', 8.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    end

    set(gca, 'XTick', 1:N, 'XTickLabel', codes, 'XTickLabelRotation', 20, 'FontSize', 8.5);
    ylabel('Annual GRB Rate [bursts / year]', 'FontSize', 10, 'FontWeight', 'bold');
    ylim([0, max(det_yr) * 1.22 + 15]);
    title('2. Annual Detection & Useful Localization Yield (Primary MOE)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'northwest', 'FontSize', 8.2);

    sgtitle('GRB Alert Mission — Physics-Based Sky Coverage, CRLB Localization & Annual Yield', ...
            'FontSize', 13, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);

    if nargin >= 4 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end
