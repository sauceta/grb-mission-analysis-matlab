function res = analyze_comms_latency(t_sec, sat_r_ecef, cfg, comms, req, const)
% ANALYZE_COMMS_LATENCY High-resolution RF link budget, ground contacts & multi-path alert latency.
% Evaluates and compares THREE alert dissemination paths (resolving SRR Action A-04):
%   Path A: Equatorial VHF Alert Network (45 SVOM-heritage stations, 137.5 MHz, 600 bps)
%   Path B: Commercial LEO Space Relay (Iridium NEXT SBD/Certus)
%   Path C: Primary S/X-band TT&C Store-and-Forward Only (5 stations)
%
% Key Physics Included:
%   - Exact WGS-84 topocentric elevation & slant range at 10 s resolution
%   - RF Link Closure budget (IF-040: EIRP 0 dBW, FSPL, Eb/N0 margin at 5 deg mask)
%   - For TDOA constellations (num_sats >= 4): computes the 4th-order statistic of wait
%     times because 2D triangulation requires timestamps from >= 4 satellites!
%   - Daily bulk science data return volume vs PHY-030 (<= 1.0 Gbit/day) & max blackout gap
%
% Verifies: MIS-040 (66% <= 30 s), MIS-050 (95% <= 20 min), OPS-020 (>= 90% cov),
%           IF-020/030/040, PHY-030, VER-050 (25th/50th/75th/95th percentiles).
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    M_sat    = cfg.num_sats;
    N_steps  = length(t_sec);
    dt_sec   = t_sec(2) - t_sec(1);
    sim_days = max((t_sec(end) - t_sec(1)) / const.sec_per_day, 1e-4);

    %% 1. VHF RF Link Budget Verification at Worst-Case 5 deg Elevation (IF-020, IF-030, IF-040)
    rf = comms.vhf_rf;
    Re_km = const.Re_km;
    h_km  = cfg.h_km;
    el_min_rad = deg2rad(5.0);
    % Exact slant range at 5 deg elevation: R = -Re*sin(el) + sqrt((Re*sin(el))^2 + 2*Re*h + h^2)
    slant_max_m = (-Re_km * sin(el_min_rad) + sqrt((Re_km * sin(el_min_rad))^2 + 2*Re_km*h_km + h_km^2)) * 1e3;
    lambda_m    = const.c / rf.freq_Hz;
    fspl_dB     = 20.0 * log10(4.0 * pi * slant_max_m / lambda_m);
    G_over_T    = comms.vhf_stations(1).G_over_T;
    kB_dBW      = 10.0 * log10(const.k_B); % -228.6 dBW/K/Hz
    Rb_dBHz     = 10.0 * log10(rf.bitrate_bps);

    ebn0_rx_dB  = rf.eirp_dBW - fspl_dB - rf.atm_pol_loss_dB + G_over_T - kB_dBW - Rb_dBHz;
    vhf_margin_dB = ebn0_rx_dB - rf.req_ebn0_dB;

    res.vhf_slant_max_km = slant_max_m * 1e-3;
    res.vhf_fspl_dB      = fspl_dB;
    res.vhf_ebn0_dB      = ebn0_rx_dB;
    res.vhf_link_margin_dB = vhf_margin_dB;
    res.vhf_link_closes  = (vhf_margin_dB >= const.link_margin_req_dB);

    % Fixed alert transmission & routing overhead [seconds]
    t_algo = cfg.onboard_proc_s;
    t_tx   = (rf.packet_bytes * 8.0 * rf.repeats) / rf.bitrate_bps; % 128B x 2 @ 600 bps = 3.41 s
    t_gcn  = 2.0; % Terrestrial routing + GCN Kafka ingestion (MIS-060)
    t_overhead_vhf = t_algo + t_tx + t_gcn;

    %% 2. Compute Per-Satellite Line-of-Sight Visibility to VHF & TT&C Networks
    vhf_vis = false(M_sat, N_steps);
    ttc_vis = false(M_sat, N_steps);
    ttc_rate_Mbps = zeros(1, N_steps); % Sat 1 instantaneous bulk downlink rate

    for s = 1:M_sat
        [vhf_vis(s, :), ~] = compute_network_visibility(sat_r_ecef{s}, comms.vhf_stations, const);
        [ttc_vis(s, :), max_r] = compute_network_visibility(sat_r_ecef{s}, comms.ttc_stations, const);
        if s == 1
            ttc_rate_Mbps = max_r;
        end
    end

    % Coverage fractions (OPS-020 >= 90%)
    res.vhf_orbit_cov_pct = 100.0 * mean(vhf_vis(1, :));
    res.ttc_orbit_cov_pct = 100.0 * mean(ttc_vis(1, :));
    res.vhf_contact_min_day = (sum(vhf_vis(1, :)) * dt_sec / 60.0) / sim_days;
    res.ttc_contact_min_day = (sum(ttc_vis(1, :)) * dt_sec / 60.0) / sim_days;

    % Daily bulk science data downlink capacity via TT&C [Gbit/day] (vs PHY-030 <= 1.0 Gbit/day)
    % Assume 80% protocol/acquisition efficiency on S/X-band passes
    res.ttc_downlink_Gb_day = (sum(ttc_rate_Mbps) * dt_sec * 1e-3 * 0.80) / sim_days;

    % Maximum TT&C communication blackout gap [min] (drives SSR storage / OPS-040)
    d_gap = diff([true, ttc_vis(1, :), true]);
    g_st  = find(d_gap == -1);
    g_en  = find(d_gap == 1) - 1;
    if ~isempty(g_st)
        res.max_ttc_gap_min = max((g_en - g_st + 1) * dt_sec) / 60.0;
    else
        res.max_ttc_gap_min = 0.0;
    end

    %% 3. Exact Alert Latency Wait Times Across Propagation Window
    T_orb_s = 2.0 * pi * sqrt((cfg.a_m^3) / const.mu);
    steps_orb = ceil(T_orb_s / dt_sec);
    N_eval = max(1, N_steps - steps_orb);

    wait_vhf_all = zeros(M_sat, N_eval);
    wait_ttc_all = zeros(M_sat, N_eval);

    for s = 1:M_sat
        next_v = compute_next_contact(vhf_vis(s, :));
        next_t = compute_next_contact(ttc_vis(s, :));

        idx_v = next_v(1:N_eval);
        idx_t = next_t(1:N_eval);

        w_v = (idx_v - (1:N_eval)) * dt_sec;
        w_v(isnan(w_v)) = T_orb_s;
        % Sub-step quantization smoothing for contiguous in-contact steps (uniform [0, dt_sec] jitter)
        wait_vhf_all(s, :) = w_v;

        w_t = (idx_t - (1:N_eval)) * dt_sec;
        w_t(isnan(w_t)) = T_orb_s;
        wait_ttc_all(s, :) = w_t;
    end

    % Effective system wait time:
    %   - Single-sat localizers: Sat 1 wait time
    %   - Twin GECAM dome: best (minimum) of the 2 nodes
    %   - TDOA Constellation (6 sats): 4th-order statistic (must receive >= 4 spacecraft timestamps!)
    if strcmp(cfg.loc_principle, 'tdoa_triangulation') && M_sat >= 4
        sorted_v = sort(wait_vhf_all, 1);
        sorted_t = sort(wait_ttc_all, 1);
        sys_wait_vhf = sorted_v(4, :); % 4th satellite to reach VHF station
        sys_wait_ttc = sorted_t(4, :);
    elseif M_sat > 1
        sys_wait_vhf = min(wait_vhf_all, [], 1);
        sys_wait_ttc = min(wait_ttc_all, [], 1);
    else
        sys_wait_vhf = wait_vhf_all(1, :);
        sys_wait_ttc = wait_ttc_all(1, :);
    end

    lat_vhf_s = sys_wait_vhf + t_overhead_vhf;
    lat_ttc_s = sys_wait_ttc + t_overhead_vhf;

    %% 4. Path B: Commercial LEO Space Relay Simulation (Iridium NEXT SBD/Certus)
    rng(9001 + cfg.id);
    N_ir = 5000;
    ir   = comms.iridium;
    if strcmp(cfg.loc_principle, 'tdoa_triangulation') && M_sat >= 4
        % 4 simultaneous spacecraft must transmit timestamps via Iridium -> max of 4 random links
        ir_draws = zeros(4, N_ir);
        for k = 1:4
            base_t = exp(log(ir.acq_median_s) + ir.acq_sigma_logn * randn(1, N_ir));
            drop   = rand(1, N_ir) > ir.availability;
            base_t(drop) = base_t(drop) + 90.0 + 180.0 * rand(1, sum(drop)); % Handover retry
            ir_draws(k, :) = base_t;
        end
        lat_iridium_s = max(ir_draws, [], 1) + t_algo + ir.gcn_broker_s;
    else
        base_t = exp(log(ir.acq_median_s) + ir.acq_sigma_logn * randn(1, N_ir));
        drop   = rand(1, N_ir) > ir.availability;
        base_t(drop) = base_t(drop) + 90.0 + 180.0 * rand(1, sum(drop));
        lat_iridium_s = base_t + t_algo + ir.gcn_broker_s;
    end

    %% 5. Compute Exact Percentiles (VER-050) & Requirement Checks (MIS-040, MIS-050)
    res.vhf = summarize_latency(lat_vhf_s, req);
    res.iridium = summarize_latency(lat_iridium_s, req);
    res.ttc = summarize_latency(lat_ttc_s, req);

    % Select primary alert path performance (VHF if low-inc meets OPS-020/MIS-040, else compare both)
    res.best_pct_30s    = max(res.vhf.pct_le_30s, res.iridium.pct_le_30s);
    res.best_median_s   = min(res.vhf.p50_s, res.iridium.p50_s);
    res.best_p75_s      = min(res.vhf.p75_s, res.iridium.p75_s);
    res.meets_mis040_vhf = (res.vhf.pct_le_30s >= req.MIS_040_alert_fast_pct);
    res.meets_mis050_vhf = (res.vhf.pct_le_20m >= req.MIS_050_alert_slow_pct);
    res.meets_mis040_ir  = (res.iridium.pct_le_30s >= req.MIS_040_alert_fast_pct);
    res.meets_ops020_vhf = (res.vhf_orbit_cov_pct >= req.OPS_020_alert_orbit_cov_pct);
end

function stats = summarize_latency(lat_s, req)
    s_lat = sort(lat_s(:)');
    N = length(s_lat);
    stats.p25_s      = s_lat(max(1, round(0.25 * N)));
    stats.p50_s      = s_lat(max(1, round(0.50 * N)));
    stats.p75_s      = s_lat(max(1, round(0.75 * N)));
    stats.p95_s      = s_lat(max(1, round(0.95 * N)));
    stats.pct_le_30s = 100.0 * mean(s_lat <= req.MIS_040_alert_fast_s);
    stats.pct_le_20m = 100.0 * mean(s_lat <= req.MIS_050_alert_slow_min * 60.0);
    % Downsample CDF to 400 clean points for lightweight storage & crisp plotting
    idx_cdf = unique(round(linspace(1, N, min(400, N))));
    stats.cdf_s    = s_lat(idx_cdf);
    stats.cdf_prob = idx_cdf / N;
end

function [in_view, max_rate_Mbps] = compute_network_visibility(r_ecef, stations, const)
    N = size(r_ecef, 2);
    in_view = false(1, N);
    max_rate_Mbps = zeros(1, N);

    a  = const.Re;
    e2 = const.e_earth^2;

    for i = 1:length(stations)
        gs  = stations(i);
        phi = deg2rad(gs.lat);
        lam = deg2rad(gs.lon);
        N_p = a / sqrt(1.0 - e2 * sin(phi)^2);

        R_gs = [(N_p + gs.alt) * cos(phi) * cos(lam);
                (N_p + gs.alt) * cos(phi) * sin(lam);
                (N_p * (1.0 - e2) + gs.alt) * sin(phi)];

        rho = r_ecef - R_gs;
        u_up = [cos(phi)*cos(lam); cos(phi)*sin(lam); sin(phi)];
        rho_mag = sqrt(sum(rho.^2, 1));
        sin_el  = (u_up' * rho) ./ rho_mag;
        vis_i   = sin_el >= sind(gs.mask);

        in_view = in_view | vis_i;
        if isfield(gs, 'rate_Mbps')
            max_rate_Mbps(vis_i) = max(max_rate_Mbps(vis_i), gs.rate_Mbps);
        end
    end
end

function next_idx = compute_next_contact(in_view)
    N = length(in_view);
    next_idx = nan(1, N);
    last_vis = NaN;
    for k = N:-1:1
        if in_view(k)
            last_vis = k;
        end
        next_idx(k) = last_vis;
    end
end
