%% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission
% MASTER MISSION ANALYSIS PIPELINE (v2.0 — Rebuilt From Scratch)
%
% Standards & Guidelines Compliance:
%   - TUM Report Guide (WS 2026/27): Orbit selection trade-off, propagation, coverage &
%     revisit, orbital lifetime, Delta-V budget, worst hot/cold cases, quantitative MCDA
%     with zero subjective scales/weights, sensitivity analysis, and verification/plausibility!
%   - ECSS-E-ST-10C Rev.1, ECSS-E-ST-10-04C, ECSS-E-ST-10-06C, ECSS-E-ST-32-10C
%   - ESA Space Debris Mitigation Standard ESSB-ST-U-007 (5-Year Post-Mission Disposal Rule)
%   - NASA/SP-2016-6105 Rev2 (Systems Engineering Handbook — Decision Analysis)
%
% Physical Fidelity:
%   - High-precision ODE113 propagation (J2 + J3 + J4 + NRLMSISE-00 drag + conical SRP + Gauss work)
%   - Live Aerospace Toolbox NRLMSISE-00 (Solar Min / Nom / Max) & IGRF-14 geomagnetic field
%   - Exact IAU-2000/2006 ECI -> WGS-84 ECEF frame alignment
%   - True 3D Fibonacci celestial sphere (N=1000) sky coverage & >=4-fold co-viewing (ARC-060)
%   - 3,000-burst Monte Carlo GRB population with Band spectra, Poisson SNR, coded-mask
%     centroiding & exact 3D TDOA Fisher Information Matrix Cramér-Rao Lower Bounds (CRLB)
%   - Multi-path alert latency CDF (45-station Equatorial VHF vs Iridium NEXT Relay vs TT&C)
%   - Objective TOPSIS MCDA across 4 weighting schemes + 10,000-trial Dirichlet sensitivity!
%
% Author: TUM Space Mission Design Team
% Date: November 2026

clear; close all; clc;
t_pipe_start = tic;

% Configure clean MATLAB paths
root_dir = fileparts(mfilename('fullpath'));
if isempty(root_dir), root_dir = pwd; end
addpath(genpath(root_dir));

out_dir = fullfile(root_dir, 'results');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

fprintf('================================================================================\n');
fprintf('  TUM SPACE MISSION DESIGN (WS 2026/27) — GRB ALERT MISSION ANALYSIS SUITE v2.0\n');
fprintf('  Aerospace-Grade Propagation | IGRF-14 | NRLMSISE-00 | 3D CRLB | TOPSIS MCDA\n');
fprintf('================================================================================\n\n');

%% STAGE 1: LOAD CONFIGURATION & BUILD LIVE PHYSICAL ENVIRONMENT MODELS
fprintf('[Stage 1/7] Building Live Environment Models (NRLMSISE-00 & IGRF-14)...\n');
const  = constants();
req    = mission_requirements();
comms  = ground_stations_config();
archs  = get_architecture_configs(const);
atmo   = build_atmosphere_model(const);
geomag = build_geomagnetic_model(const);
fprintf('   -> Atmosphere : %s (500 km rho: Min=%.2e, Nom=%.2e, Max=%.2e kg/m^3)\n', ...
    atmo.source, atmosphere_density(500, atmo, 'solar_min'), ...
    atmosphere_density(500, atmo, 'solar_nom'), atmosphere_density(500, atmo, 'solar_max'));
fprintf('   -> Geomag     : %s\n\n', geomag.source);

%% STAGE 2: AUTOMATED VERIFICATION & LITERATURE PLAUSIBILITY SUITE (Report Guide p. 5)
fprintf('[Stage 2/7] Executing Verification & Literature Plausibility Checks...\n');
ver = verify_mission_analysis(const, atmo, geomag, comms, req);
for k = 1:length(ver.tests)
    st = 'FAIL'; if ver.tests(k).passed, st = 'PASS'; end
    fprintf('   [%s] %-58s | %s\n', st, ver.tests(k).name, ver.tests(k).numerical);
end
fprintf('   -> Verification Summary: %d / %d PASSED\n\n', ver.n_passed, ver.n_total);

%% STAGE 3: 2D PARAMETRIC ORBIT SELECTION TRADE STUDY (Altitude x Inclination)
fprintf('[Stage 3/7] Running Parametric 2D Orbit Trade Space (99 circular LEO orbits)...\n');
trade_orb = analyze_orbit_trade_space(geomag, atmo, comms, req, const);
fprintf('   -> Evaluated %d x %d grid (400-650 km x 0-97.4 deg). Feasible corridor: %d orbits.\n\n', ...
    length(trade_orb.inc_grid_deg), length(trade_orb.h_grid_km), sum(trade_orb.feasible_mask(:)));

%% STAGE 4: HIGH-FIDELITY MULTI-DAY PROPAGATION & SUBSYSTEM ANALYSES (6 ARCHITECTURES)
% 5 days at 10 s resolution -> 43,201 epochs (~75 orbits) for crisp alert latency & SAA statistics
sim_days = 5.0;
dt_step  = 10.0;
tspan    = 0.0:dt_step:(sim_days * const.sec_per_day);
prop_opts = struct('enable_J2', true, 'enable_J3', true, 'enable_J4', true, ...
                   'enable_drag', true, 'enable_srp', true, 'solar_regime', 'solar_nom');

N_arch = length(archs);
results = struct();

fprintf('[Stage 4/7] Propagating & Analyzing All %d Candidate Architectures (%.0f days @ %.0f s)...\n', ...
    N_arch, sim_days, dt_step);

for i = 1:N_arch
    cfg = archs(i);
    t_a = tic;
    fprintf('   -> [%d/%d] %s (%d sat%s, %.0f km, %.1f deg)... ', ...
        i, N_arch, cfg.name, cfg.num_sats, ternary_s(cfg.num_sats > 1, 's', ''), cfg.h_km, cfg.inc_deg);

    M_sat = cfg.num_sats;
    sat_r_eci  = cell(1, M_sat);
    sat_v_eci  = cell(1, M_sat);
    sat_r_ecef = cell(1, M_sat);
    sat_lat    = zeros(M_sat, length(tspan));
    sat_lon    = zeros(M_sat, length(tspan));
    sat_alt_m  = zeros(M_sat, length(tspan));
    decay_rates = zeros(1, M_sat);

    for s = 1:M_sat
        raan_s = cfg.raan_deg(min(s, length(cfg.raan_deg)));
        nu_s   = cfg.nu_deg(min(s, length(cfg.nu_deg)));
        [r0, v0] = kep2cart(cfg.a_m, cfg.e, cfg.inc_deg, raan_s, cfg.omega_deg, nu_s, const.mu);
        [t_out, r_eci, v_eci, diag_p] = orbit_propagator(r0, v0, tspan, cfg, const, atmo, prop_opts);
        [r_ecef, ~] = eci2ecef_iau(r_eci, v_eci, t_out, const);
        [lat_d, lon_d, alt_m] = ecef2lla_wgs84(r_ecef, const);

        sat_r_eci{s}   = r_eci;
        sat_v_eci{s}   = v_eci;
        sat_r_ecef{s}  = r_ecef;
        sat_lat(s, :)  = lat_d;
        sat_lon(s, :)  = lon_d;
        sat_alt_m(s,:) = alt_m;
        decay_rates(s) = diag_p.decay_rate_m_yr;
    end

    % Run all coupled physical mission analysis modules
    rad_res   = analyze_radiation_saa(tspan, sat_lat, sat_lon, sat_alt_m, geomag);
    ecl_res   = analyze_eclipse_annual(tspan, sat_r_eci{1}, sat_v_eci{1}, cfg, const);
    cov_res   = analyze_sky_coverage_3d(tspan, sat_r_eci, rad_res.in_radiation, cfg, req, const);
    loc_res   = analyze_localization_yield(sat_r_eci, rad_res.in_radiation, cov_res, rad_res, cfg, req, const);
    comms_res = analyze_comms_latency(tspan, sat_r_ecef, cfg, comms, req, const);
    life_res  = analyze_lifetime_deltav(cfg, mean(decay_rates), const, atmo, req);

    % Pack consolidated result record
    results(i).id                        = cfg.id;
    results(i).code                      = cfg.code;
    results(i).name                      = cfg.name;
    results(i).short_name                = cfg.short_name;
    results(i).archetype                 = cfg.archetype;
    results(i).num_sats                  = cfg.num_sats;
    results(i).h_km                      = cfg.h_km;
    results(i).inc_deg                   = cfg.inc_deg;
    results(i).mass_wet_kg               = cfg.mass_wet_kg;
    results(i).mass_total_kg             = cfg.mass_total_kg;
    results(i).cost_MUSD_nom             = cfg.cost_MUSD_nom;
    results(i).cost_MUSD_unc             = cfg.cost_MUSD_unc;
    results(i).trl                       = cfg.trl;

    % Headline flattened KPIs for easy vector indexing & MCDA
    results(i).annual_detected_bursts    = loc_res.annual_detected_bursts;
    results(i).annual_localized_10am     = loc_res.annual_localized_10am;
    results(i).annual_localized_3am      = loc_res.annual_localized_3am;
    results(i).r90_median_arcmin         = loc_res.r90_median_arcmin;
    results(i).r90_at_snr8_median_arcmin = loc_res.r90_at_snr8_median_arcmin;
    results(i).r90_samples_arcmin        = loc_res.r90_samples_arcmin;
    results(i).net_observing_duty_pct    = cov_res.net_observing_duty_pct;
    results(i).annual_exposure_sr_yr     = cov_res.annual_exposure_sr_yr;
    results(i).mean_4fold_sky_pct        = cov_res.mean_4fold_sky_pct;
    results(i).vhf_pct_le_30s            = comms_res.vhf.pct_le_30s;
    results(i).vhf_pct_le_20m            = comms_res.vhf.pct_le_20m;
    results(i).iridium_pct_le_30s        = comms_res.iridium.pct_le_30s;
    results(i).iridium_pct_le_20m        = comms_res.iridium.pct_le_20m;
    results(i).best_alert_pct_30s        = comms_res.best_pct_30s;
    results(i).best_alert_p75_s          = comms_res.best_p75_s;
    results(i).dv_total_ms               = life_res.dv_total_ms;
    results(i).meets_essb_5yr            = life_res.meets_essb_5yr;

    % Detailed sub-structs
    results(i).cfg   = cfg;
    results(i).rad   = rad_res;
    results(i).ecl   = ecl_res;
    results(i).cov   = cov_res;
    results(i).loc   = loc_res;
    results(i).comms = comms_res;
    results(i).life  = life_res;

    % Generate architecture-specific ground track & annual eclipse/beta figures
    f_gt = plot_ground_track(sat_lat, sat_lon, cfg, geomag, comms, const, ...
                             fullfile(out_dir, sprintf('Ground_Track_%s.png', cfg.code)));
    close(f_gt);

    f_ec = plot_eclipse_beta_annual(ecl_res, cfg, const, ...
                                    fullfile(out_dir, sprintf('Annual_Beta_Eclipse_%s.png', cfg.code)));
    close(f_ec);

    fprintf('done (%.1fs | Yield=%.1f/yr, r90=%.1f'', VHF<=30s=%.0f%%, dV=%.0f m/s)\n', ...
        toc(t_a), loc_res.annual_localized_10am, loc_res.r90_at_snr8_median_arcmin, ...
        comms_res.vhf.pct_le_30s, life_res.dv_total_ms);
end
fprintf('\n');

%% STAGE 5: MULTI-CRITERIA DECISION ANALYSIS (TOPSIS + 10,000-TRIAL SENSITIVITY)
fprintf('[Stage 5/7] Executing Report-Guide-Compliant TOPSIS MCDA & Sensitivity Analysis...\n');
mcda = evaluate_tradeoff_study(results, req);
fprintf('   -> Selected Baseline Architecture: %s\n\n', mcda.recommended_name);

%% STAGE 6: GENERATE COMPARATIVE PUBLICATION FIGURES (300/250 DPI TUM PALETTE)
fprintf('[Stage 6/7] Rendering Publication-Grade Figures...\n');
f1 = plot_orbit_trade_maps(trade_orb, results, const, fullfile(out_dir, 'Orbit_Trade_Space_Maps.png'));
close(f1);
f2 = plot_sky_coverage_localization(results, req, const, fullfile(out_dir, 'Localization_and_Yield_Comparison.png'));
close(f2);
f3 = plot_alert_latency_cdf(results, req, const, fullfile(out_dir, 'Alert_Latency_CDF_Trade.png'));
close(f3);
f4 = plot_lifetime_debris(results, req, const, fullfile(out_dir, 'Lifetime_and_DeltaV_Budget.png'));
close(f4);
f5 = plot_tradeoff_dashboard(results, mcda, req, const, fullfile(out_dir, 'Tradeoff_MCDA_Dashboard.png'));
close(f5);

%% STAGE 7: EXPORT SUBSYSTEM JSON, CSV, LATEX TABLES, MARKDOWN REPORT & MAT ARCHIVE
fprintf('[Stage 7/7] Exporting Deliverables (JSON, CSV, LaTeX tables, MD report, MAT)...\n');
export_deliverables(results, mcda, ver, trade_orb, const, out_dir);
save(fullfile(out_dir, 'Mission_Analysis_v2_Results.mat'), 'results', 'mcda', 'ver', 'trade_orb', 'const', 'req');

%% CONSOLE SUMMARY REPORT
fprintf('\n================================================================================\n');
fprintf('  REQUIREMENTS SCREENING & MULTI-CRITERIA DECISION SUMMARY\n');
fprintf('================================================================================\n');
fprintf('| Code   | Architecture            | Yield/yr | r90(8s) | Duty  | VHF30s | Irid30s | dV m/s | Gates | WinProb |\n');
fprintf('| :----- | :---------------------- | -------: | ------: | ----: | -----: | ------: | -----: | :---: | ------: |\n');
for i = 1:N_arch
    r = results(i);
    fprintf('| %-6s | %-23s | %8.1f | %6.1f'' | %4.1f%% | %5.1f%% | %6.1f%% | %6.1f |  %d/7  |  %5.1f%% |\n', ...
        r.code, r.short_name, r.annual_localized_10am, r.r90_at_snr8_median_arcmin, ...
        r.net_observing_duty_pct, r.vhf_pct_le_30s, r.iridium_pct_le_30s, ...
        r.dv_total_ms, mcda.screening(i).n_passed, mcda.mc_win_prob_pass_pct(i));
end

fprintf('\nTOPSIS Scores across 4 Objective Weighting Scenarios:\n');
fprintf('| Weighting Scheme          | ARCH-1 | ARCH-2 | ARCH-3 | ARCH-4 | ARCH-5 | ARCH-6 |\n');
fprintf('| :------------------------ | -----: | -----: | -----: | -----: | -----: | -----: |\n');
for s = 1:4
    fprintf('| %-25s | %6.3f | %6.3f | %6.3f | %6.3f | %6.3f | %6.3f |\n', ...
        mcda.weight_names{s}, mcda.topsis_scores(s, 1), mcda.topsis_scores(s, 2), ...
        mcda.topsis_scores(s, 3), mcda.topsis_scores(s, 4), mcda.topsis_scores(s, 5), mcda.topsis_scores(s, 6));
end

fprintf('\n>>> RECOMMENDED BASELINE: %s\n', mcda.recommended_name);
fprintf('>>> Total pipeline execution time: %.1f seconds. All artifacts saved to ./results/\n\n', toc(t_pipe_start));

function out = ternary_s(cond, a, b)
    if cond, out = a; else, out = b; end
end
