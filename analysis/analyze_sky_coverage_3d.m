function res = analyze_sky_coverage_3d(t_sec, sat_r_eci, in_radiation, cfg, req, const)
% ANALYZE_SKY_COVERAGE_3D First-principles 3D celestial sphere visibility & exposure simulator.
% Evaluates N_sky = 1000 isotropic Fibonacci-sphere celestial directions across EVERY
% satellite in the architecture at 60 s cadence over the multi-day propagated timeline:
%   - Earth limb occultation (including 80 km gamma-ray absorbing atmosphere)
%   - Sun (35 deg) & Moon (10 deg) exclusion constraints (OPS-060)
%   - Boresight pointing law (SVOM-like anti-solar / zenith-biased, or nadir-opposite zenith)
%   - Instrument FoV half-cone aperture (cfg.fov_half_angle_deg)
%   - Per-satellite active state (excluding IGRF-14 SAA & polar horn blanking)
%
% Directly computes:
%   - Instantaneous 1-fold, 2-fold, 3-fold, and >=4-fold simultaneous sky coverage (ARC-060!)
%   - Net observing duty cycle (PER-070 >= 60%)
%   - Integrated annual sky exposure [sr*yr] (SRR.tex feasibility > 2.0 sr*yr!)
%   - Per-epoch, per-satellite active boresight & visibility state for Monte Carlo GRB yield!
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    %% 1. Construct Uniform Fibonacci Celestial Sphere (N_sky = 1000 pixels)
    N_sky = 1000;
    idx   = (0:(N_sky-1))' + 0.5;
    golden_angle = pi * (3.0 - sqrt(5.0));
    z_sky = 1.0 - 2.0 * idx / N_sky;
    r_xy  = sqrt(max(0.0, 1.0 - z_sky.^2));
    phi_k = golden_angle * idx;
    U_sky = [r_xy .* cos(phi_k), r_xy .* sin(phi_k), z_sky]'; % 3 x N_sky unit vectors

    %% 2. Subsample Timeline to 60 s Cadence (fast vectorized BLAS matrix ops)
    dt_sim = t_sec(2) - t_sec(1);
    stride = max(1, round(60.0 / dt_sim));
    t_sub_idx = 1:stride:length(t_sec);
    t_sub = t_sec(t_sub_idx);
    N_t   = length(t_sub);
    M_sat = cfg.num_sats;

    mjd_sub = const.epoch_mjd + t_sub / const.sec_per_day;
    [u_sun, ~, u_moon, ~] = sun_moon_ephemeris(mjd_sub, const);

    % Geometric thresholds
    R_earth_eff = const.Re + 80.0e3; % 80 km gamma-ray absorption limb [m]
    cos_fov     = cosd(cfg.fov_half_angle_deg);

    % Optical/coded-mask imagers enforce Sun/Moon avoidance (OPS-060);
    % wide-angle uncollimated gamma scintillators have relaxed Sun exclusion (15 deg)
    if strcmp(cfg.loc_principle, 'coded_mask') || strcmp(cfg.loc_principle, 'lobster_eye')
        cos_sun_excl  = cosd(req.OPS_060_sun_excl_deg);
        cos_moon_excl = cosd(req.OPS_060_moon_excl_deg);
    else
        cos_sun_excl  = cosd(15.0);
        cos_moon_excl = cosd(5.0);
    end

    %% 3. Evaluate 3D Visibility Across All Satellites and Epochs
    % Track cumulative exposure per sky pixel & instantaneous k-fold coverage counts
    sky_exp_1fold  = zeros(1, N_sky);
    sky_exp_4fold  = zeros(1, N_sky);
    cov_frac_1fold = zeros(1, N_t);
    cov_frac_3fold = zeros(1, N_t);
    cov_frac_4fold = zeros(1, N_t);
    active_any_sat = false(1, N_t);
    earth_occ_acc  = 0.0;

    % Store boresight vectors for Monte Carlo GRB localization module
    boresights = cell(1, M_sat);
    for s = 1:M_sat
        boresights{s} = zeros(3, N_t);
    end

    % Precompute nadir & boresight vectors for every satellite
    u_zenith_all = cell(1, M_sat);
    cos_limb_all = cell(1, M_sat);
    active_all   = cell(1, M_sat);

    for s = 1:M_sat
        r_s = sat_r_eci{s}(:, t_sub_idx);
        r_m = sqrt(sum(r_s.^2, 1));
        u_z = r_s ./ r_m; % Zenith unit vector (+r_hat)
        u_zenith_all{s} = u_z;
        % Earth limb occultation: sky vector s is occulted if dot(s, -u_z) > cos(rho_E)
        % i.e., UNOCCULTED if dot(s, u_z) > -cos(rho_E) = -sqrt(1 - (Re_eff/r)^2)
        cos_limb_all{s} = -sqrt(max(0.0, 1.0 - (R_earth_eff ./ r_m).^2));
        active_all{s}   = ~in_radiation(s, t_sub_idx);

        if strcmp(cfg.pointing_law, 'anti_solar')
            % SVOM B1-style anti-solar survey law with automatic Earth-limb avoidance:
            % Point toward -u_sun when above Earth horizon; else slew smoothly toward zenith
            b_s = -u_sun;
            dot_bz = sum(b_s .* u_z, 1);
            blocked = dot_bz < 0.25; % Near/below Earth limb -> blend toward zenith
            if any(blocked)
                b_blend = -0.35 * u_sun(:, blocked) + 0.94 * u_z(:, blocked);
                b_s(:, blocked) = b_blend ./ sqrt(sum(b_blend.^2, 1));
            end
            boresights{s} = b_s;
        else
            % Zenith-pointing staring monitor (HERMES / GECAM)
            boresights{s} = u_z;
        end
    end

    % Loop over epochs (fast vectorized 1000-pixel operations per epoch)
    for k = 1:N_t
        % Sun & Moon exclusion mask across 1000 sky pixels (1 x N_sky)
        sun_ok  = (u_sun(:, k)'  * U_sky) < cos_sun_excl;
        moon_ok = (u_moon(:, k)' * U_sky) < cos_moon_excl;
        celest_ok = sun_ok & moon_ok;

        n_viewers = zeros(1, N_sky);
        for s = 1:M_sat
            uz_k = u_zenith_all{s}(:, k);
            dot_z = uz_k' * U_sky; % 1 x N_sky
            unocculted = (dot_z > cos_limb_all{s}(k));

            if s == 1
                earth_occ_acc = earth_occ_acc + (1.0 - mean(unocculted));
            end

            if active_all{s}(k)
                in_fov = (boresights{s}(:, k)' * U_sky) >= cos_fov;
                vis_s  = unocculted & in_fov & celest_ok;
                n_viewers = n_viewers + double(vis_s);
            end
        end

        seen1 = (n_viewers >= 1);
        seen3 = (n_viewers >= 3);
        seen4 = (n_viewers >= 4);

        cov_frac_1fold(k) = mean(seen1);
        cov_frac_3fold(k) = mean(seen3);
        cov_frac_4fold(k) = mean(seen4);
        active_any_sat(k) = any(seen1);

        sky_exp_1fold = sky_exp_1fold + double(seen1);
        sky_exp_4fold = sky_exp_4fold + double(seen4);
    end

    % Operational platform uptime factor (~96%: housekeeping, calibration, safe-mode margin)
    eta_ops = 0.96;

    res.t_sub_sec               = t_sub;
    res.t_sub_idx               = t_sub_idx;
    res.U_sky                   = U_sky;
    res.boresights              = boresights;
    res.cos_fov                 = cos_fov;
    res.cos_sun_excl            = cos_sun_excl;
    res.cos_moon_excl           = cos_moon_excl;
    res.earth_occult_pct        = 100.0 * (earth_occ_acc / N_t);
    res.unocculted_sky_sr       = 4.0 * pi * (1.0 - earth_occ_acc / N_t);

    % Mean instantaneous sky coverage (including active radiation duty cycle!)
    res.mean_active_sky_pct     = 100.0 * mean(cov_frac_1fold) * eta_ops;
    res.mean_active_sky_sr      = 4.0 * pi * mean(cov_frac_1fold) * eta_ops;
    res.peak_inst_sky_pct       = 100.0 * max(cov_frac_1fold);
    res.peak_inst_sky_sr        = 4.0 * pi * max(cov_frac_1fold);

    % Multi-satellite simultaneous co-viewing fractions (verifies ARC-060!)
    res.mean_3fold_sky_pct      = 100.0 * mean(cov_frac_3fold) * eta_ops;
    res.mean_4fold_sky_pct      = 100.0 * mean(cov_frac_4fold) * eta_ops;
    res.peak_4fold_sky_pct      = 100.0 * max(cov_frac_4fold);

    % Net observing duty cycle (fraction of mission time actively observing sky, PER-070 >= 60%)
    res.net_observing_duty_pct  = 100.0 * mean(active_any_sat) * eta_ops;

    % Integrated annual sky-time exposure [sr * yr] (SRR.tex target > 2.0 sr*yr)
    res.annual_exposure_sr_yr   = 4.0 * pi * mean(cov_frac_1fold) * eta_ops;

    % Fractional exposure map across the 1000 Fibonacci sky pixels
    res.sky_exposure_map_1fold  = (sky_exp_1fold / N_t) * eta_ops;
    res.sky_exposure_map_4fold  = (sky_exp_4fold / N_t) * eta_ops;
end
