function export_deliverables(results, mcda, ver, trade_orb, const, out_dir)
% EXPORT_DELIVERABLES Generates clean engineering handoff files for subsystems & LaTeX report.
% Exports:
%   1. results/Subsystem_Inputs.json         (Power, Simscape Thermal, Propulsion, Comms, OBDH, ADCS)
%   2. results/Mission_Analysis_Summary.csv  (Full quantitative KPI table)
%   3. results/tables/mission_analysis_table.tex (Ready-to-\input TUM-styled LaTeX table)
%   4. results/tables/verification_table.tex     (Ready-to-\input Verification & Plausibility table)
%   5. results/Mission_Analysis_Report.md        (Full Markdown quantitative report)
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    tbl_dir = fullfile(out_dir, 'tables');
    if ~exist(tbl_dir, 'dir'), mkdir(tbl_dir); end

    N = length(results);

    %% 1. Export Subsystem Interface JSON (for Power, Simscape Thermal, Propulsion, Comms, OBDH)
    sub_out = struct();
    sub_out.metadata.mission      = 'TUM Space Mission Design (WS 2026/27) — GRB Alert Mission';
    sub_out.metadata.epoch_utc    = sprintf('%04d-%02d-%02d %02d:%02d:%02d UTC', const.epoch_utc);
    sub_out.metadata.recommended  = mcda.recommended_name;
    sub_out.metadata.verification = sprintf('%d/%d PASS', ver.n_passed, ver.n_total);

    for i = 1:N
        r = results(i);
        s = struct();
        s.code                   = r.code;
        s.name                   = r.name;
        s.orbit.altitude_km      = r.h_km;
        s.orbit.inclination_deg  = r.inc_deg;
        s.orbit.period_min       = r.ecl.T_orbit_min;
        s.orbit.raan_dot_deg_day = r.ecl.raan_dot_deg_day;
        s.power_thermal.worst_cold_eclipse_min = round(r.ecl.worst_cold_eclipse_min, 2);
        s.power_thermal.worst_hot_eclipse_min  = round(r.ecl.worst_hot_eclipse_min, 2);
        s.power_thermal.mean_sunlight_yr_pct   = round(r.ecl.mean_sunlight_yr_pct, 2);
        s.power_thermal.beta_max_abs_deg       = round(r.ecl.beta_max_abs_deg, 2);
        s.power_thermal.full_sun_days_per_yr   = round(r.ecl.full_sun_days_per_yr, 1);
        s.propulsion.dv_injection_ms           = round(r.life.dv_injection_ms, 2);
        s.propulsion.dv_phasing_ms             = round(r.life.dv_phasing_ms, 2);
        s.propulsion.dv_drag_max_ms            = round(r.life.dv_drag_max_ms, 2);
        s.propulsion.dv_cam_ms                 = round(r.life.dv_cam_ms, 2);
        s.propulsion.dv_disposal_ms            = round(r.life.dv_disposal_ms, 2);
        s.propulsion.dv_total_with_margin_ms   = round(r.life.dv_total_ms, 2);
        s.propulsion.prop_mass_per_sat_kg      = round(r.life.prop_per_sat_kg, 2);
        s.propulsion.disposal_strategy         = r.life.disposal_strategy;
        s.propulsion.natural_life_smin_yr      = round(r.life.life_solar_min_yr, 2);
        s.comms_obdh.vhf_orbit_cov_pct         = round(r.comms.vhf_orbit_cov_pct, 2);
        s.comms_obdh.vhf_median_lat_s          = round(r.comms.vhf.p50_s, 1);
        s.comms_obdh.vhf_pct_le_30s            = round(r.comms.vhf.pct_le_30s, 1);
        s.comms_obdh.iridium_pct_le_30s        = round(r.comms.iridium.pct_le_30s, 1);
        s.comms_obdh.vhf_link_margin_dB        = round(r.comms.vhf_link_margin_dB, 2);
        s.comms_obdh.ttc_contact_min_day       = round(r.comms.ttc_contact_min_day, 1);
        s.comms_obdh.ttc_max_gap_min           = round(r.comms.max_ttc_gap_min, 1);
        s.comms_obdh.ttc_downlink_Gb_day       = round(r.comms.ttc_downlink_Gb_day, 2);
        s.science.annual_detected_bursts       = round(r.annual_detected_bursts, 1);
        s.science.annual_localized_10am        = round(r.annual_localized_10am, 1);
        s.science.r90_at_snr8_median_arcmin    = round(r.r90_at_snr8_median_arcmin, 2);
        s.science.net_observing_duty_pct       = round(r.net_observing_duty_pct, 1);
        s.science.annual_exposure_sr_yr        = round(r.annual_exposure_sr_yr, 2);
        s.science.saa_loss_pct                 = round(r.rad.saa_fraction_pct, 2);
        s.science.polar_loss_pct               = round(r.rad.polar_fraction_pct, 2);
        s.science.rel_proton_dose_index        = round(r.rad.rel_proton_dose_index, 2);
        sub_out.architectures.(sprintf('arch_%d', i)) = s;
    end

    json_str = jsonencode(sub_out, 'PrettyPrint', true);
    fid = fopen(fullfile(out_dir, 'Subsystem_Inputs.json'), 'w');
    fprintf(fid, '%s\n', json_str);
    fclose(fid);

    %% 2. Export Quantitative CSV Table
    fid = fopen(fullfile(out_dir, 'Mission_Analysis_Summary.csv'), 'w');
    fprintf(fid, ['Code,Architecture,NumSats,Alt_km,Inc_deg,TotalMass_kg,Cost_MUSD,TRL,' ...
                  'Detected_yr,Localized_10am_yr,r90_SNR8_arcmin,NetDuty_pct,Exposure_sryr,' ...
                  'SAA_Loss_pct,Polar_Loss_pct,WorstColdEcl_min,VHF_Cov_pct,VHF_Pct30s,' ...
                  'Iridium_Pct30s,Life_SolarMin_yr,DeltaV_Total_ms,PropPerSat_kg,' ...
                  'Screen_Pass,TOPSIS_Equal,TOPSIS_Entropy,TOPSIS_Science,TOPSIS_SmallSat,MC_WinProb_Pass_pct\n']);
    for i = 1:N
        r = results(i);
        fprintf(fid, '%s,"%s",%d,%.1f,%.1f,%.1f,%.1f,%d,%.1f,%.1f,%.2f,%.1f,%.2f,%.1f,%.1f,%.2f,%.1f,%.1f,%.1f,%.2f,%.1f,%.2f,%d,%.3f,%.3f,%.3f,%.3f,%.1f\n', ...
            r.code, r.short_name, r.num_sats, r.h_km, r.inc_deg, r.mass_total_kg, r.cost_MUSD_nom, r.trl, ...
            r.annual_detected_bursts, r.annual_localized_10am, r.r90_at_snr8_median_arcmin, ...
            r.net_observing_duty_pct, r.annual_exposure_sr_yr, r.rad.saa_fraction_pct, r.rad.polar_fraction_pct, ...
            r.ecl.worst_cold_eclipse_min, r.comms.vhf_orbit_cov_pct, r.comms.vhf.pct_le_30s, ...
            r.comms.iridium.pct_le_30s, r.life.life_solar_min_yr, r.life.dv_total_ms, r.life.prop_per_sat_kg, ...
            mcda.screening(i).passed_all, mcda.topsis_scores(1,i), mcda.topsis_scores(2,i), ...
            mcda.topsis_scores(3,i), mcda.topsis_scores(4,i), mcda.mc_win_prob_pass_pct(i));
    end
    fclose(fid);

    %% 3. Export LaTeX Booktabs Table for SRR / Final Report
    fid = fopen(fullfile(tbl_dir, 'mission_analysis_table.tex'), 'w');
    fprintf(fid, '%% Auto-generated by MATLAB Mission Analysis Suite v2.0 (%s)\n', datestr(now, 'yyyy-mm-dd'));
    fprintf(fid, '\\begin{table}[htbp]\n\\centering\\small\n');
    fprintf(fid, '\\caption{Quantitative Mission Analysis and Architecture Trade-Off Summary.}\n');
    fprintf(fid, '\\label{tab:mission_analysis_tradeoff}\n');
    fprintf(fid, '\\begin{tabular}{@{}lcccccc@{}}\n\\toprule\n');
    fprintf(fid, '\\textbf{Metric (Unit)} & \\textbf{ARCH-1} & \\textbf{ARCH-2} & \\textbf{ARCH-3} & \\textbf{ARCH-4} & \\textbf{ARCH-5} & \\textbf{ARCH-6} \\\\\n');
    fprintf(fid, ' & SmallSat CM & Monolith CM & TDOA (6x) & Lobster-Eye & GECAM Dome & SSO SmallSat \\\\\n\\midrule\n');
    fprintf(fid, 'Orbit ($h$ [km], $i$ [$^\\circ$]) & %.0f / %.1f & %.0f / %.1f & %.0f / %.1f & %.0f / %.1f & %.0f / %.1f & %.0f / %.1f \\\\\n', ...
        results(1).h_km, results(1).inc_deg, results(2).h_km, results(2).inc_deg, results(3).h_km, results(3).inc_deg, ...
        results(4).h_km, results(4).inc_deg, results(5).h_km, results(5).inc_deg, results(6).h_km, results(6).inc_deg);
    fprintf(fid, 'Total Wet Mass [kg] & %.0f & %.0f & %.0f & %.0f & %.0f & %.0f \\\\\n', [results.mass_total_kg]);
    fprintf(fid, 'Est. Cost [M USD] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.cost_MUSD_nom]);
    fprintf(fid, 'Localized GRBs ($\\le 10^\\prime$) [yr$^{-1}$] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.annual_localized_10am]);
    fprintf(fid, 'Median $r_{90}$ ($\\text{SNR}\\ge 8$) [$^\\prime$] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.r90_at_snr8_median_arcmin]);
    fprintf(fid, 'Net Observing Duty Cycle [\\%%] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.net_observing_duty_pct]);
    fprintf(fid, 'VHF Alert $\\le 30\\,\\text{s}$ [\\%%] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.vhf_pct_le_30s]);
    fprintf(fid, 'Iridium Relay $\\le 30\\,\\text{s}$ [\\%%] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.iridium_pct_le_30s]);
    fprintf(fid, 'Worst Cold Eclipse [min] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', arrayfun(@(x) x.ecl.worst_cold_eclipse_min, results));
    fprintf(fid, 'Solar-Min Natural Life [yr] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', arrayfun(@(x) x.life.life_solar_min_yr, results));
    fprintf(fid, 'Total $\\Delta v$ (+10\\%%) [m/s] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', [results.dv_total_ms]);
    fprintf(fid, 'Req. Screening (7 Gates) & %d/7 & %d/7 & %d/7 & %d/7 & %d/7 & %d/7 \\\\\n', [mcda.screening.n_passed]);
    fprintf(fid, 'TOPSIS (SmallSat / Science) & %.2f / %.2f & %.2f / %.2f & %.2f / %.2f & %.2f / %.2f & %.2f / %.2f & %.2f / %.2f \\\\\n', ...
        mcda.topsis_scores(4,1), mcda.topsis_scores(3,1), mcda.topsis_scores(4,2), mcda.topsis_scores(3,2), ...
        mcda.topsis_scores(4,3), mcda.topsis_scores(3,3), mcda.topsis_scores(4,4), mcda.topsis_scores(3,4), ...
        mcda.topsis_scores(4,5), mcda.topsis_scores(3,5), mcda.topsis_scores(4,6), mcda.topsis_scores(3,6));
    fprintf(fid, 'MC Win Prob. (Screened) [\\%%] & %.1f & %.1f & %.1f & %.1f & %.1f & %.1f \\\\\n', mcda.mc_win_prob_pass_pct);
    fprintf(fid, '\\bottomrule\n\\end{tabular}\n\\end{table}\n');
    fclose(fid);

    %% 4. Export Verification Table LaTeX
    fid = fopen(fullfile(tbl_dir, 'verification_table.tex'), 'w');
    fprintf(fid, '%% Auto-generated Verification & Plausibility Table (Report Guide p. 5)\n');
    fprintf(fid, '\\begin{table}[htbp]\n\\centering\\small\n');
    fprintf(fid, '\\caption{Mission Analysis Software Verification and Literature Plausibility Checks.}\n');
    fprintf(fid, '\\label{tab:mission_analysis_verification}\n');
    fprintf(fid, '\\begin{tabular}{@{}llllc@{}}\n\\toprule\n');
    fprintf(fid, '\\textbf{ID} & \\textbf{Verification / Plausibility Check} & \\textbf{Simulation Output} & \\textbf{Analytical / Literature Ref.} & \\textbf{Status} \\\\\n\\midrule\n');
    for k = 1:length(ver.tests)
        t = ver.tests(k);
        st = 'FAIL'; if t.passed, st = 'PASS'; end
        fprintf(fid, '%s & %s & %s & %s & \\textbf{%s} \\\\\n', ...
            t.id, strrep(t.name, '&', '\&'), strrep(t.numerical, '%', '\%'), strrep(t.reference, '%', '\%'), st);
    end
    fprintf(fid, '\\bottomrule\n\\end{tabular}\n\\end{table}\n');
    fclose(fid);

    %% 5. Export Full Markdown Engineering Summary Report
    fid = fopen(fullfile(out_dir, 'Mission_Analysis_Report.md'), 'w');
    fprintf(fid, '# TUM Space Mission Design (WS 2026/27) — GRB Alert Mission Analysis Report (v2.0)\n\n');
    fprintf(fid, 'Generated automatically on %s using MATLAB R2026a + Aerospace Toolbox (NRLMSISE-00, IGRF-14, IAU-2000/2006).\n\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    fprintf(fid, '## 1. Automated Verification & Literature Plausibility Checks (%d/%d PASSED)\n\n', ver.n_passed, ver.n_total);
    fprintf(fid, '| ID | Check | Numerical Output | Analytical / Literature Benchmark | Status |\n| :--- | :--- | :--- | :--- | :--- |\n');
    for k = 1:length(ver.tests)
        t = ver.tests(k);
        st = 'FAIL'; if t.passed, st = 'PASS'; end
        fprintf(fid, '| %s | %s | %s | %s | **%s** |\n', t.id, t.name, t.numerical, t.reference, st);
    end
    fprintf(fid, '\n## 2. Architecture Screening & Quantitative Comparison\n\n');
    fprintf(fid, '| Code | Architecture | Orbit | Mass [kg] | Cost [M$] | Yield <=10'' [/yr] | r90 (SNR>=8) | Duty [%%] | VHF <=30s | Iridium <=30s | Delta-V [m/s] | Screening |\n');
    fprintf(fid, '| :--- | :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |\n');
    for i = 1:N
        r = results(i);
        fprintf(fid, '| %s | %s | %dkm/%.1f° | %.0f | %.1f | %.1f | %.1f'' | %.1f%% | %.1f%% | %.1f%% | %.1f | %s |\n', ...
            r.code, r.short_name, round(r.h_km), r.inc_deg, r.mass_total_kg, r.cost_MUSD_nom, ...
            r.annual_localized_10am, r.r90_at_snr8_median_arcmin, r.net_observing_duty_pct, ...
            r.comms.vhf.pct_le_30s, r.comms.iridium.pct_le_30s, r.life.dv_total_ms, mcda.screening(i).status);
    end
    fprintf(fid, '\n## 3. Recommended Baseline\n\n**Selected Architecture:** `%s`\n', mcda.recommended_name);
    fprintf(fid, '\nFeasible 2D Orbit Corridor points found: %d / %d tested (Altitude 400–650 km x Inclination 0–97.4 deg).\n', ...
            sum(trade_orb.feasible_mask(:)), numel(trade_orb.feasible_mask));
    fclose(fid);
end
