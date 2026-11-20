function res = analyze_localization_yield(sat_r_eci, in_radiation, cov_res, rad_res, cfg, req, const)
% ANALYZE_LOCALIZATION_YIELD First-principles Monte Carlo GRB Population, SNR & Localization Error Budget.
% Resolves SRR Action A-03 and verifies MIS-020 (>= 40 GRBs/yr), MIS-030 / PER-010 (r90 <= 10' at SNR>=8).
%
% Physical Pipeline (N_MC = 3,000 simulated isotropic cosmic GRBs):
%   1. Cosmic GRB Population:
%      - All-sky rate R_allsky = 900 GRBs/yr above P_1s >= 0.25 ph/cm^2/s (15-150 keV;
%        calibrated to BATSE / Fermi GBM ~230/yr & Swift BAT ~90/yr catalogues)
%      - Broken power-law logN-logP flux distribution
%      - Band-function spectral E_peak distribution (85% long: 144 keV, 15% short: 413 keV, SRR.tex [S4])
%   2. 3D Visibility & Poisson SNR Evaluation:
%      - Checks exact instantaneous Earth occultation, Sun/Moon exclusion, instrument FoV,
%        off-axis cosine response, and IGRF-14 radiation blanking across ALL satellites
%      - Computes Poisson SNR with orbit-dependent background rate (rad_res.bg_rate_cts_cm2_s)
%   3. Physics-Based 90% Localization Error Radius r90 [arcmin]:
%      - Coded-Mask   : Fenimore-Cannon centroiding (FWHM / SNR) (+) systematic floor (+) ADCS knowledge
%      - TDOA Const.  : Exact 3D Cramér-Rao Lower Bound (Fisher Information Matrix) across the ACTUAL
%                       instantaneous 3D ECI baseline vectors r_i(t) of the >=3 triggered satellites!
%      - Lobster-Eye  : Soft X-ray Band spectral tail conversion + MPO PSF centroiding (+) ADCS
%      - Count-Ratio  : Connaughton et al. (2015) ApJS 216, 32 empirical core (3.71 deg) + tail (14.3 deg)
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    rng(20261120 + cfg.id); % Deterministic reproducible seed per architecture

    N_MC      = 3000;
    R_allsky  = 900.0; % Cosmic GRBs/yr across 4*pi sr above P_min = 0.25 ph/cm^2/s (15-150 keV)
    eta_ops   = 0.96;  % Platform operational uptime

    t_sub_idx = cov_res.t_sub_idx;
    N_t       = length(t_sub_idx);
    M_sat     = cfg.num_sats;

    % Precompute Sun/Moon vectors at subsampled epochs
    mjd_sub = const.epoch_mjd + cov_res.t_sub_sec / const.sec_per_day;
    [u_sun, ~, u_moon, ~] = sun_moon_ephemeris(mjd_sub, const);
    R_earth_eff = const.Re + 80.0e3;

    %% 1. Draw Synthetic Isotropic Cosmic GRB Population
    % Random burst epochs & isotropic sky directions
    ep_idx = randi(N_t, 1, N_MC);
    z_b    = 2.0 * rand(1, N_MC) - 1.0;
    phi_b  = 2.0 * pi * rand(1, N_MC);
    r_xy_b = sqrt(max(0.0, 1.0 - z_b.^2));
    U_burst = [r_xy_b .* cos(phi_b); r_xy_b .* sin(phi_b); z_b]; % 3 x N_MC

    % Broken power-law logN-logP peak flux P_1s [ph/cm^2/s in 15-150 keV]
    % P_min = 0.25, P_break = 2.0, slope1 = -0.85 (faint), slope2 = -1.55 (bright)
    u_flux = rand(1, N_MC);
    P_flux = sample_grb_flux(u_flux);

    % Band-function spectral E_peak [keV]: 85% long (median 144 keV), 15% short (median 413 keV)
    is_short = rand(1, N_MC) < 0.15;
    E_peak = zeros(1, N_MC);
    E_peak(~is_short) = exp(log(144.0) + 0.65 * randn(1, sum(~is_short)));
    E_peak(is_short)  = exp(log(413.0) + 0.55 * randn(1, sum(is_short)));
    E_peak = max(15.0, min(3000.0, E_peak));

    % Effective trigger integration time [s]: short ~0.25 s, long ~1.5 s
    t_int = 1.5 * ones(1, N_MC);
    t_int(is_short) = 0.25;

    % Band-pass photon conversion factor relative to canonical 15-150 keV reference band
    f_band = compute_band_conversion(E_peak, cfg.energy_band_keV(1), cfg.energy_band_keV(2));

    %% 2. Simulate Detection & Physics-Based Localization for Every Burst
    detected_flag = false(1, N_MC);
    r90_arcmin    = nan(1, N_MC);
    snr_best      = zeros(1, N_MC);
    n_det_sats    = zeros(1, N_MC);

    bg_rate = rad_res.bg_rate_cts_cm2_s; % [cts/cm^2/s]
    k90     = sqrt(-2.0 * log(0.10));    % = 2.14597 (2D Rayleigh 90% containment radius / 1D sigma)

    for b = 1:N_MC
        k_t  = ep_idx(b);
        n_hat = U_burst(:, b);

        % Check Sun/Moon exclusion
        if (dot(n_hat, u_sun(:, k_t)) >= cov_res.cos_sun_excl) || ...
           (dot(n_hat, u_moon(:, k_t)) >= cov_res.cos_moon_excl)
            continue;
        end

        % Check each satellite's visibility & SNR
        det_idx = [];
        det_snr = [];
        det_cos = [];
        det_pos = [];

        for s = 1:M_sat
            t_full_i = t_sub_idx(k_t);
            if in_radiation(s, t_full_i)
                continue; % Blanked in SAA or polar horn
            end

            r_s   = sat_r_eci{s}(:, t_full_i);
            r_mag = norm(r_s);
            u_z   = r_s / r_mag;

            % Earth limb occultation check
            cos_limb = -sqrt(max(0.0, 1.0 - (R_earth_eff / r_mag)^2));
            if dot(n_hat, u_z) <= cos_limb
                continue;
            end

            % Instrument FoV & off-axis projection
            cos_off = dot(n_hat, cov_res.boresights{s}(:, k_t));
            if cos_off < cov_res.cos_fov
                continue;
            end

            % Compute Poisson detection SNR
            if strcmp(cfg.loc_principle, 'lobster_eye')
                % Focusing optics (Einstein Probe WXT): integrates soft X-rays over 20-30 s
                % into a ~5 arcmin focal PSF cell with tiny background (~0.008 cts/s per PSF cell!)
                t_wxt = 25.0; % Soft X-ray prompt + early-afterglow trigger integration [s]
                if is_short(b), t_wxt = 1.0; end % Short hard GRBs lack extended soft X-ray emission
                sig_cts = P_flux(b) * f_band(b) * cfg.A_eff_cm2 * max(cos_off, 0.30) * t_wxt;
                bg_cts  = 0.008 * t_wxt; % Focused CMOS PSF background counts
                snr_s   = sig_cts / sqrt(bg_cts + sig_cts);
            else
                % Coded-aperture SNR (Skinner 2008 / Fenimore & Cannon):
                % cfg.A_eff_cm2 ALREADY represents the mask-coded open effective area (PER-050 >= 300 cm^2,
                % e.g. SVOM ECLAIRs ~340 cm^2 on ~1024 cm^2 CdTe plane); diffuse background illuminates
                % the full detector area A_det = A_eff / open_frac (open_frac ~ 0.45 for coded masks).
                if strcmp(cfg.loc_principle, 'coded_mask')
                    bg_area_cm2 = cfg.A_eff_cm2 / 0.45;
                else
                    bg_area_cm2 = cfg.A_eff_cm2;
                end
                sig_cts = P_flux(b) * f_band(b) * cfg.A_eff_cm2 * max(cos_off, 0.25) * t_int(b);
                bg_cts  = bg_rate * bg_area_cm2 * t_int(b);
                snr_s   = sig_cts / sqrt(max(bg_cts + sig_cts, 1e-6));
            end

            if snr_s >= req.PER_100_trigger_snr
                det_idx(end+1) = s; %#ok<AGROW>
                det_snr(end+1) = snr_s; %#ok<AGROW>
                det_cos(end+1) = cos_off; %#ok<AGROW>
                det_pos(:, end+1) = r_s; %#ok<AGROW>
            end
        end

        n_d = length(det_idx);
        if n_d == 0
            continue;
        end

        detected_flag(b) = true;
        n_det_sats(b)    = n_d;
        [snr_max, i_best] = max(det_snr);
        snr_best(b)      = snr_max;

        % Compute 90% Localization Error Radius r90 [arcmin] from Instrument Physics
        switch cfg.loc_principle
            case 'coded_mask'
                % Fenimore-Cannon coded-mask centroiding: sigma_1d = 0.42 * FWHM / (SNR * sqrt(cos_off))
                sig_stat_am = 0.42 * cfg.mask_fwhm_arcmin / (snr_max * sqrt(max(det_cos(i_best), 0.25)));
                sig_adcs_am = cfg.adcs_know_arcsec / 60.0;
                r90_arcmin(b) = sqrt((k90 * sig_stat_am)^2 + cfg.loc_sys_arcmin^2 + (k90 * sig_adcs_am)^2);

            case 'lobster_eye'
                sig_stat_am = 0.42 * cfg.psf_fwhm_arcmin / max(snr_max, 1.0);
                sig_adcs_am = cfg.adcs_know_arcsec / 60.0;
                r90_arcmin(b) = sqrt((k90 * sig_stat_am)^2 + cfg.loc_sys_arcmin^2 + (k90 * sig_adcs_am)^2);

            case 'tdoa_triangulation'
                % Exact 3D Fisher Information Matrix / Cramér-Rao Lower Bound (CRLB)
                % Requires >= 3 non-collinear satellites (>= 4 for unambiguous 2D sky localization per ARC-060)
                if n_d >= 4
                    r90_arcmin(b) = compute_tdoa_crlb_r90(n_hat, det_pos, det_snr, cfg, const, k90);
                elseif n_d == 3
                    % 3 satellites yield two mirror intersections; Earth occultation resolves ~65% of cases
                    if rand() < 0.65
                        r90_arcmin(b) = compute_tdoa_crlb_r90(n_hat, det_pos, det_snr, cfg, const, k90);
                    else
                        r90_arcmin(b) = 180.0; % Unresolved mirror ambiguity
                    end
                else
                    % 1 or 2 satellites -> 1D annulus only (cannot localize to a 2D point!)
                    r90_arcmin(b) = 600.0;
                end

            case 'count_rate_ratio'
                % Connaughton et al. (2015) ApJS 216, 32 empirical core + tail systematic error
                if rand() < 0.90
                    sig_sys_deg = cfg.loc_sys_core_deg;
                else
                    sig_sys_deg = cfg.loc_sys_tail_deg;
                end
                sig_stat_deg  = 14.0 / max(snr_max, 1.0);
                % Core value in Connaughton is 1-sigma -> convert to 90% containment
                r90_arcmin(b) = 60.0 * k90 * sqrt(sig_sys_deg^2 + sig_stat_deg^2) / 1.515;
        end
    end

    %% 3. Aggregate Annual Yields & Localization Percentiles
    scale_to_yr = (R_allsky / N_MC) * eta_ops;

    det_r90  = r90_arcmin(detected_flag);
    det_snrs = snr_best(detected_flag);

    loc_10_mask = detected_flag & (r90_arcmin <= req.MIS_030_loc_r90_arcmin);
    loc_3_mask  = detected_flag & (r90_arcmin <= req.MIS_030_goal_arcmin);
    snr8_mask   = detected_flag & (snr_best >= req.PER_010_min_snr);

    res.annual_detected_bursts  = sum(detected_flag) * scale_to_yr;
    res.annual_localized_10am   = sum(loc_10_mask)   * scale_to_yr; % PRIMARY MOE (MIS-020 >= 40/yr)
    res.annual_localized_3am    = sum(loc_3_mask)    * scale_to_yr; % Goal (MIS-030 <= 3')

    if ~isempty(det_r90)
        res.r90_median_arcmin = median(det_r90);
        res.r90_p90_arcmin    = prctile_simple(det_r90, 90.0);
        res.frac_loc_10am_pct = 100.0 * mean(det_r90 <= req.MIS_030_loc_r90_arcmin);
    else
        res.r90_median_arcmin = Inf;
        res.r90_p90_arcmin    = Inf;
        res.frac_loc_10am_pct = 0.0;
    end

    if any(snr8_mask)
        res.r90_at_snr8_median_arcmin = median(r90_arcmin(snr8_mask));
        res.r90_at_snr8_p75_arcmin    = prctile_simple(r90_arcmin(snr8_mask), 75.0);
    else
        res.r90_at_snr8_median_arcmin = Inf;
        res.r90_at_snr8_p75_arcmin    = Inf;
    end

    res.r90_samples_arcmin   = det_r90;
    res.snr_samples          = det_snrs;
    res.mean_coview_on_trig  = mean(n_det_sats(detected_flag));
    res.meets_mis020         = (res.annual_localized_10am >= req.MIS_020_min_bursts_per_yr);
    res.meets_mis030_per010  = (res.r90_at_snr8_median_arcmin <= req.PER_010_loc_r90_at_snr8_arcmin);
end

function r90_am = compute_tdoa_crlb_r90(n_hat, det_pos, det_snr, cfg, const, k90)
    % Exact 3D Cramér-Rao Lower Bound for TDOA triangulation across M >= 3 satellites
    M = size(det_pos, 2);

    % Build orthonormal tangent basis (e1, e2) on celestial sphere at burst direction n_hat
    if abs(n_hat(3)) < 0.9
        ref = [0; 0; 1];
    else
        ref = [1; 0; 0];
    end
    e1 = cross(ref, n_hat); e1 = e1 / norm(e1);
    e2 = cross(n_hat, e1);  e2 = e2 / norm(e2);

    % Reference satellite = highest-SNR detector
    [~, i_ref] = max(det_snr);
    r_ref = det_pos(:, i_ref);
    other_idx = setdiff(1:M, i_ref);

    % Per-satellite arrival-time 1-sigma error [s]: clock accuracy (+) cross-correlation jitter
    % Cross-correlation timing jitter scales inversely with burst SNR (Fiore et al. 2020)
    sig_t_all = sqrt((cfg.clock_acc_us * 1e-6)^2 + ((cfg.cc_timing_ref_us * 1e-6) .* (10.0 ./ max(det_snr, 1.0))).^2);
    sig_ref2  = sig_t_all(i_ref)^2;

    K = length(other_idx);
    J = zeros(K, 2);
    for m = 1:K
        d_m = det_pos(:, other_idx(m)) - r_ref; % 3D baseline vector [m]
        J(m, 1) = -(dot(d_m, e1)) / const.c;
        J(m, 2) = -(dot(d_m, e2)) / const.c;
    end

    % Exact differential TDOA covariance matrix: Cov(dt_m, dt_n) = sig_ref^2 + delta_mn * sig_m^2
    Sigma_t = sig_ref2 * ones(K, K) + diag(sig_t_all(other_idx).^2);

    % Fisher Information Matrix FIM = J' * inv(Sigma_t) * J
    FIM = J' * (Sigma_t \ J);

    % Check geometric conditioning (collinear satellites -> singular FIM -> annulus)
    if rcond(FIM) < 1e-8
        r90_am = 600.0;
        return;
    end

    Cov_theta = inv(FIM); % 2x2 angular covariance [rad^2]
    % Equivalent circular 1-sigma radius from error ellipse area: sigma_eq = det(Cov)^(1/4)
    det_cov = max(det(Cov_theta), 0.0);
    sig_eq_rad = det_cov^(0.25);
    sig_eq_am  = rad2deg(sig_eq_rad) * 60.0;

    r90_am = min(600.0, sqrt((k90 * sig_eq_am)^2 + cfg.loc_sys_arcmin^2));
end

function P = sample_grb_flux(u)
    % Inverse-CDF sampling of broken power-law GRB peak flux (15-150 keV, ph/cm^2/s)
    % Calibrated so Swift BAT (~1.4 sr, 0.4 ph/cm^2/s threshold) detects ~85-95 GRBs/yr
    % and Fermi GBM (~8.5 sr unocculted) detects ~230-260 GRBs/yr.
    P_min = 0.25; P_brk = 2.0; P_max = 100.0;
    a1 = 0.85; a2 = 1.55;
    % Cumulative weights for two power-law segments (pdf ~ P^-(a+1))
    w1 = (P_min^(-a1) - P_brk^(-a1)) / a1;
    c_match = P_brk^(a2 - a1); % Continuity at P_brk
    w2 = c_match * (P_brk^(-a2) - P_max^(-a2)) / a2;
    p1 = w1 / (w1 + w2);

    P = zeros(size(u));
    m1 = u <= p1;
    u1 = u(m1) / p1;
    P(m1) = (P_min^(-a1) - u1 * (P_min^(-a1) - P_brk^(-a1))).^(-1.0 / a1);

    u2 = (u(~m1) - p1) / (1.0 - p1);
    P(~m1) = (P_brk^(-a2) - u2 * (P_brk^(-a2) - P_max^(-a2))).^(-1.0 / a2);
end

function f_conv = compute_band_conversion(E_peak, E_lo, E_hi)
    % Integrates canonical Band function (alpha = -1.0, beta = -2.3) photon flux
    % in [E_lo, E_hi] relative to reference [15, 150] keV band.
    N = length(E_peak);
    f_conv = zeros(1, N);
    E_ref_grid = logspace(log10(15.0), log10(150.0), 30);
    E_ins_grid = logspace(log10(E_lo), log10(E_hi), 30);

    alpha = -1.0; beta = -2.3;
    for i = 1:N
        E0 = E_peak(i) / (2.0 + alpha);
        Eb = (alpha - beta) * E0;
        phi_ref = band_spec(E_ref_grid, alpha, beta, E0, Eb);
        phi_ins = band_spec(E_ins_grid, alpha, beta, E0, Eb);
        f_ref = trapz(E_ref_grid, phi_ref);
        f_ins = trapz(E_ins_grid, phi_ins);
        f_conv(i) = f_ins / max(f_ref, 1e-12);
    end
    % Soft X-ray galactic/intrinsic absorption factor below 4 keV
    if E_hi <= 10.0
        % ~35% of Band prompt/early soft X-ray flux escapes neutral H column absorption (N_H ~ 10^21 cm^-2)
        f_conv = f_conv * 0.35;
    end
end

function phi = band_spec(E, alpha, beta, E0, Eb)
    phi = zeros(size(E));
    lo = E <= Eb;
    phi(lo)  = (E(lo) / 100.0).^alpha .* exp(-E(lo) / E0);
    phi(~lo) = ((Eb / 100.0)^(alpha - beta)) * exp(beta - alpha) .* (E(~lo) / 100.0).^beta;
end

function q = prctile_simple(x, p)
    xs = sort(x(:));
    n  = length(xs);
    idx = max(1, min(n, round((p / 100.0) * n)));
    q = xs(idx);
end
