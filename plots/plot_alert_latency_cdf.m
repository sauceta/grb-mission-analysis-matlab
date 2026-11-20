function fig = plot_alert_latency_cdf(results, req, const, out_png)
% PLOT_ALERT_LATENCY_CDF Multi-path alert dissemination latency CDF (VHF vs Iridium vs TT&C).
% Directly verifies MIS-040 (66% <= 30 s, Goal 90%), MIS-050 (95% <= 20 min), and VER-050.

    fig = figure('Name', 'Alert Dissemination Latency Trade', ...
                 'Units', 'pixels', 'Position', [80, 60, 1260, 560], 'Visible', 'off', 'Color', 'w');

    % Reference baseline = ARCH-1 (SmallSat Low-Inc), ARCH-3 (TDOA 6-sat), ARCH-6 (SSO)
    r1 = results(1);
    r3 = results(3);
    r6 = results(6);

    %% Panel 1: Multi-Path Latency CDF Comparison
    subplot(1, 2, 1);
    hold on; grid on; box on;

    semilogx(r1.comms.vhf.cdf_s, r1.comms.vhf.cdf_prob * 100, '-', 'Color', const.colors.TUMBlue, 'LineWidth', 2.4, ...
             'DisplayName', sprintf('ARCH-1 VHF Chain (%.1f%% <=30s, med %.1fs)', r1.comms.vhf.pct_le_30s, r1.comms.vhf.p50_s));
    semilogx(r1.comms.iridium.cdf_s, r1.comms.iridium.cdf_prob * 100, '--', 'Color', const.colors.TUMGreen, 'LineWidth', 2.2, ...
             'DisplayName', sprintf('ARCH-1 Iridium Relay (%.1f%% <=30s, med %.1fs)', r1.comms.iridium.pct_le_30s, r1.comms.iridium.p50_s));
    semilogx(r3.comms.vhf.cdf_s, r3.comms.vhf.cdf_prob * 100, '-.', 'Color', const.colors.TUMOrange, 'LineWidth', 2.0, ...
             'DisplayName', sprintf('ARCH-3 TDOA 4-Sat VHF (%.1f%% <=30s, med %.1fs)', r3.comms.vhf.pct_le_30s, r3.comms.vhf.p50_s));
    semilogx(r6.comms.vhf.cdf_s, r6.comms.vhf.cdf_prob * 100, ':', 'Color', const.colors.TUMPurple, 'LineWidth', 2.1, ...
             'DisplayName', sprintf('ARCH-6 SSO on VHF Chain (%.1f%% <=30s, med %.0fs)', r6.comms.vhf.pct_le_30s, r6.comms.vhf.p50_s));
    semilogx(r1.comms.ttc.cdf_s, r1.comms.ttc.cdf_prob * 100, '-', 'Color', const.colors.TUMGray, 'LineWidth', 1.6, ...
             'DisplayName', sprintf('ARCH-1 TT&C Store-Fwd Only (med %.1f min)', r1.comms.ttc.p50_s/60));

    set(gca, 'XScale', 'log');
    xline(req.MIS_040_alert_fast_s, '--', 'Color', const.colors.TUMRed, 'LineWidth', 1.8, 'DisplayName', 'MIS-040 Limit (30 s)');
    xline(req.MIS_050_alert_slow_min * 60, '-.', 'Color', [0.55 0.1 0.1], 'LineWidth', 1.5, 'DisplayName', 'MIS-050 Limit (20 min)');
    yline(req.MIS_040_alert_fast_pct, ':', 'Color', const.colors.TUMRed, 'LineWidth', 1.3, 'HandleVisibility', 'off');
    text(6.2, 68.5, 'MIS-040: 66%', 'Color', const.colors.TUMRed, 'FontWeight', 'bold', 'FontSize', 8.5);
    yline(req.MIS_050_alert_slow_pct, ':', 'Color', [0.55 0.1 0.1], 'LineWidth', 1.2, 'HandleVisibility', 'off');
    text(6.2, 97.0, 'MIS-050: 95%', 'Color', [0.55 0.1 0.1], 'FontWeight', 'bold', 'FontSize', 8.5);

    xlim([5.0, 12000.0]); ylim([0, 103]);
    xlabel('End-to-End Alert Latency to GCN Broker [seconds] (log scale)', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Cumulative Trigger Fraction [%]', 'FontSize', 10, 'FontWeight', 'bold');
    title('1. Alert Dissemination Latency CDF (VHF vs Iridium vs TT&C)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'southeast', 'FontSize', 7.5);

    %% Panel 2: Fraction Delivered <= 30 s Across All 6 Architectures (VHF vs Iridium Relay)
    subplot(1, 2, 2);
    N = length(results);
    pct_vhf = [results.vhf_pct_le_30s];
    pct_ir  = [results.iridium_pct_le_30s];
    names   = {results.short_name};

    b = bar(1:N, [pct_vhf; pct_ir]', 'grouped');
    b(1).FaceColor = const.colors.TUMBlue;
    b(1).DisplayName = 'Equatorial VHF Network (45 sites, 600 bps)';
    b(2).FaceColor = const.colors.TUMGreen;
    b(2).DisplayName = 'Commercial LEO Relay (Iridium NEXT SBD)';
    hold on; grid on; box on;

    yline(req.MIS_040_alert_fast_pct, '--', 'Color', const.colors.TUMRed, 'LineWidth', 1.9, ...
          'DisplayName', 'MIS-040 Threshold (66% \leq 30 s)');
    yline(req.MIS_040_alert_fast_goal_pct, ':', 'Color', const.colors.TUMDark, 'LineWidth', 1.5, ...
          'DisplayName', 'MIS-040 Goal (90% \leq 30 s)');

    for i = 1:N
        text(i - 0.16, pct_vhf(i) + 2.2, sprintf('%.0f%%', pct_vhf(i)), 'HorizontalAlignment', 'center', 'FontSize', 7.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
        text(i + 0.16, pct_ir(i)  + 2.2, sprintf('%.0f%%', pct_ir(i)),  'HorizontalAlignment', 'center', 'FontSize', 7.5, 'FontWeight', 'bold', 'Color', [0.15 0.4 0.05]);
    end

    set(gca, 'XTick', 1:N, 'XTickLabel', names, 'XTickLabelRotation', 20, 'FontSize', 8.5);
    ylabel('Fraction of Triggers Delivered \leq 30 s [%]', 'FontSize', 10, 'FontWeight', 'bold');
    ylim([0, 112]);
    title('2. Fast Alert Compliance (MIS-040) — Ground Chain vs Space Relay', 'FontSize', 11, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'southoutside', 'NumColumns', 2, 'FontSize', 8.0);

    sgtitle(sprintf('GRB Alert Mission — Alert Latency Verification (VHF 5^\\circ Link Margin = +%.1f dB)', r1.comms.vhf_link_margin_dB), ...
            'FontSize', 13, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);

    if nargin >= 4 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end
