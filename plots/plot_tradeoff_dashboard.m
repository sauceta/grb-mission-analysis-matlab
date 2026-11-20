function fig = plot_tradeoff_dashboard(results, mcda, req, const, out_png)
% PLOT_TRADEOFF_DASHBOARD Publication-grade 2x2 Multi-Criteria Decision Analysis Dashboard.
% Compliant with TUM Report Guide p. 4 (quantitative KPIs, zero subjective weights, full sensitivity):
%   Panel 1: Requirements Screening Gate Heatmap (PASS/FAIL across all 7 hard requirements)
%   Panel 2: TOPSIS Closeness Coefficient C* across 4 Objective Weighting Scenarios
%   Panel 3: 10,000-Trial Dirichlet Monte Carlo Weight-Space Sensitivity (Win Probability %)
%   Panel 4: Cost-Effectiveness Pareto Frontier (Localized GRBs/yr vs Lifecycle Cost & Mass)

    fig = figure('Name', 'Architecture Trade-Off MCDA Dashboard', ...
                 'Units', 'pixels', 'Position', [50, 40, 1340, 840], 'Visible', 'off', 'Color', 'w');

    N = length(results);
    short_names = {results.short_name};
    codes       = {results.code};

    %% Panel 1: Hard Requirements Screening Matrix Heatmap
    subplot(2, 2, 1);
    gate_mat = zeros(N, 7);
    for i = 1:N
        sc = mcda.screening(i);
        gate_mat(i, :) = [sc.G1_yield, sc.G2_loc10, sc.G3_lat30s, sc.G4_lat20m, ...
                          sc.G5_duty60, sc.G6_inc30, sc.G7_esa5yr];
    end
    imagesc(gate_mat);
    colormap(gca, [0.88 0.25 0.25; 0.24 0.68 0.34]);
    clim([0, 1]);
    hold on;
    for r = 1:N
        for c = 1:7
            if gate_mat(r, c) == 1
                lbl = 'PASS';
            else
                lbl = 'FAIL';
            end
            text(c, r, lbl, 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 8.5);
        end
    end
    for r = 0.5:1:(N+0.5), yline(r, 'w-', 'LineWidth', 1.5); end
    for c = 0.5:1:7.5,     xline(c, 'w-', 'LineWidth', 1.5); end

    gate_labels = {'MIS-020\newline\geq40/yr', 'MIS-030\newliner_{90}\leq10''', 'MIS-040\newline\leq30s', ...
                   'MIS-050\newline\leq20m', 'PER-070\newline\geq60%', 'ENV-050\newlinei\leq30^{\circ}', 'LIF-010\newline5-Yr'};
    set(gca, 'XTick', 1:7, 'XTickLabel', gate_labels, 'YTick', 1:N, 'YTickLabel', short_names, 'FontSize', 8.2);
    title('1. Hard Requirements Screening Matrix (7 Mandatory Gates)', 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);

    %% Panel 2: TOPSIS Closeness Coefficient C* Across 4 Weighting Scenarios
    subplot(2, 2, 2);
    b2 = bar(1:N, mcda.topsis_scores', 'grouped');
    sc_cols = [const.colors.TUMBlue; const.colors.TUMGreen; const.colors.TUMOrange; const.colors.TUMNavy];
    for s = 1:4
        b2(s).FaceColor   = sc_cols(s, :);
        b2(s).DisplayName = mcda.weight_names{s};
    end
    hold on; grid on; box on;
    set(gca, 'XTick', 1:N, 'XTickLabel', codes, 'FontSize', 9);
    ylabel('TOPSIS Closeness Score C* [0–1]', 'FontSize', 9.5, 'FontWeight', 'bold');
    ylim([0, 1.05]);
    title('2. Quantitative TOPSIS Scores (4 Weighting Scenarios)', 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'northeast', 'FontSize', 7.8);

    %% Panel 3: 10,000-Trial Dirichlet Monte Carlo Sensitivity (Win Probability %)
    subplot(2, 2, 3);
    win_pass = mcda.mc_win_prob_pass_pct;
    win_all  = mcda.mc_win_prob_all_pct;
    b3 = bar(1:N, [win_pass; win_all]', 'grouped');
    b3(1).FaceColor   = const.colors.TUMBlue;
    b3(1).DisplayName = 'Screened Feasible Pool Only (Compliant)';
    b3(2).FaceColor   = const.colors.TUMLight;
    b3(2).EdgeColor   = const.colors.TUMDark;
    b3(2).DisplayName = 'Unscreened Full Pool (Reference)';
    hold on; grid on; box on;
    for i = 1:N
        if win_pass(i) > 0.5
            text(i - 0.16, win_pass(i) + 2.5, sprintf('%.1f%%', win_pass(i)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
        end
    end
    set(gca, 'XTick', 1:N, 'XTickLabel', short_names, 'XTickLabelRotation', 18, 'FontSize', 8.2);
    ylabel('Rank-1 Win Probability [%] (10,000 Trials)', 'FontSize', 9.5, 'FontWeight', 'bold');
    ylim([0, 112]);
    title('3. Monte Carlo Dirichlet Weight-Space Sensitivity Analysis', 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'northeast', 'FontSize', 8.0);

    %% Panel 4: Cost-Effectiveness Pareto Frontier (Yield vs Lifecycle Cost & Mass)
    subplot(2, 2, 4);
    hold on; grid on; box on;
    costs  = [results.cost_MUSD_nom];
    yields = [results.annual_localized_10am];
    masses = [results.mass_total_kg];
    passed = [mcda.screening.passed_all];

    % Shaded SmallSat Sweet-Spot Zone (Cost <= $20M, Yield >= 40 GRBs/yr)
    patch([1, req.PROG_smallsat_cost_cap_MUSD, req.PROG_smallsat_cost_cap_MUSD, 1], ...
          [req.MIS_020_min_bursts_per_yr, req.MIS_020_min_bursts_per_yr, max(yields)*1.3+25, max(yields)*1.3+25], ...
          [0.85, 0.96, 0.86], 'FaceAlpha', 0.45, 'EdgeColor', const.colors.TUMGreen, 'LineStyle', '--', ...
          'DisplayName', 'SRR Target Sweet Spot (<$20M, \geq40 GRBs/yr)');

    lbl_dy = [6, -10, 8, 6, 8, -9];
    for i = 1:N
        sz = 45 + 16 * sqrt(masses(i));
        if passed(i)
            fc = const.colors.TUMBlue;
            ec = const.colors.TUMNavy;
            mk = 'o';
        else
            fc = [0.85, 0.40, 0.40];
            ec = const.colors.TUMRed;
            mk = 's';
        end
        scatter(costs(i), yields(i), sz, 'Marker', mk, 'MarkerFaceColor', fc, ...
                'MarkerEdgeColor', ec, 'LineWidth', 1.4, 'HandleVisibility', 'off');
        text(costs(i) * 1.09, yields(i) + lbl_dy(i), sprintf('%s (%dkg)', codes{i}, round(masses(i))), ...
             'FontSize', 7.8, 'FontWeight', 'bold', 'Color', ec, 'BackgroundColor', [1 1 1 0.72], 'Margin', 1);
    end
    set(gca, 'XScale', 'log');
    xline(req.PROG_smallsat_cost_cap_MUSD, '--', 'Color', const.colors.TUMGreen, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    yline(req.MIS_020_min_bursts_per_yr, '--', 'Color', const.colors.TUMRed, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xlim([8, 420]); ylim([-12, max(yields)*1.28 + 20]);
    xlabel('Estimated Mission Lifecycle Cost [M USD] (log scale)', 'FontSize', 9.5, 'FontWeight', 'bold');
    ylabel('Usefully Localized GRBs / Year (r_{90} \leq 10'')', 'FontSize', 9.5, 'FontWeight', 'bold');
    title('4. Science Return vs Cost & Mass Pareto (Bubble \propto Mass)', 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'northwest', 'FontSize', 8.0);

    sgtitle(sprintf('GRB Alert Mission — Multi-Criteria Trade-Off & Sensitivity Dashboard (Selected: %s)', ...
            mcda.recommended_name), 'FontSize', 13, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);

    if nargin >= 5 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end
