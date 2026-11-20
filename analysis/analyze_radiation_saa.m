function res = analyze_radiation_saa(t_sec, sat_lat, sat_lon, sat_alt_m, geomag)
% ANALYZE_RADIATION_SAA Evaluates IGRF-14 geomagnetic radiation blanking (SAA + Polar Horns).
% Models BOTH:
%   1. Inner Van Allen trapped proton belt (South Atlantic Anomaly, altitude-dependent |B| < B_crit)
%   2. Outer Van Allen polar/auroral electron horns (McIlwain L > 3.2, |lam_mag| > ~55 deg)
%
% Supports single satellites and multi-satellite constellations (MxN arrays).
%
% Inputs:
%   t_sec     - Time vector [s] (1xN)
%   sat_lat   - Geodetic latitude [deg] (MxN)
%   sat_lon   - Geodetic longitude [deg] (MxN)
%   sat_alt_m - Geodetic altitude [m] (MxN)
%   geomag    - Pre-built IGRF-14 interpolant struct from build_geomagnetic_model()
%
% Output struct res:
%   in_saa, in_polar, in_radiation (MxN logical)
%   saa_fraction_pct, polar_fraction_pct, total_rad_loss_pct, science_rad_duty_pct
%   saa_time_min_day, polar_time_min_day, saa_passes_per_day, max_saa_pass_min
%   rel_proton_dose_index (normalized to Swift 600 km, 20.6 deg = 1.0)
%   bg_rate_cts_cm2_s     (orbit-averaged nominal non-SAA background rate [cts/cm^2/s])

    [M, N] = size(sat_lat);
    dt_sec = t_sec(2) - t_sec(1);
    sim_days = max((t_sec(end) - t_sec(1)) / 86400.0, 1e-4);

    alt_km = sat_alt_m * 1e-3;
    B_nT   = geomag.F_B(sat_lat, sat_lon, alt_km);
    L_val  = geomag.F_L(sat_lat, sat_lon, alt_km);

    % 1. Inner Van Allen Proton Belt (SAA) — naturally expands with altitude since B ~ r^-3!
    in_saa = (B_nT < geomag.B_saa_crit_nT) & ...
             (L_val >= geomag.L_saa_min) & (L_val <= geomag.L_saa_max) & ...
             (sat_lat < 12.0) & (sat_lon > -115.0) & (sat_lon < 45.0);

    % 2. Outer Van Allen Electron Polar/Auroral Horns (L > 3.2)
    in_polar = (L_val > geomag.L_polar_crit);

    % Combined detector high-voltage / trigger blanking state
    in_rad = in_saa | in_polar;

    res.in_saa       = in_saa;
    res.in_polar     = in_polar;
    res.in_radiation = in_rad;
    res.B_nT_sat1    = B_nT(1, :);
    res.L_sat1       = L_val(1, :);

    % Mean per-satellite statistics across the constellation
    res.saa_fraction_pct     = 100.0 * mean(in_saa(:));
    res.polar_fraction_pct   = 100.0 * mean(in_polar(:));
    res.total_rad_loss_pct   = 100.0 * mean(in_rad(:));
    res.science_rad_duty_pct = 100.0 - res.total_rad_loss_pct;

    res.saa_time_min_day     = (sum(in_saa(1, :))   * dt_sec / 60.0) / sim_days;
    res.polar_time_min_day   = (sum(in_polar(1, :)) * dt_sec / 60.0) / sim_days;

    % Count SAA passes & max continuous blanking duration (Sat 1)
    d_saa  = diff([false, in_saa(1, :), false]);
    starts = find(d_saa == 1);
    ends   = find(d_saa == -1) - 1;
    res.saa_passes_per_day = length(starts) / sim_days;
    if ~isempty(starts)
        res.max_saa_pass_min = max((ends - starts + 1) * dt_sec) / 60.0;
    else
        res.max_saa_pass_min = 0.0;
    end

    % Relative trapped-proton & polar-particle radiation dose proxy (ENV-030 / GRBAlpha drift risk)
    % Trapped proton flux grows exponentially with depth into the magnetic anomaly (B_crit - B)
    proton_flux_proxy = zeros(size(B_nT));
    proton_flux_proxy(in_saa) = exp((geomag.B_saa_crit_nT - B_nT(in_saa)) / 1800.0);
    polar_flux_proxy = 0.35 * double(in_polar); % High-energy auroral electron bremsstrahlung contribution
    % Normalized such that Swift (600 km, 20.6 deg) ~ 1.00
    raw_dose = mean(proton_flux_proxy(:) + polar_flux_proxy(:));
    res.rel_proton_dose_index = raw_dose / 0.28;

    % Mean in-orbit non-SAA gamma-ray background count rate [cts/cm^2/s] (ENV-010 <= 1.5 nominal)
    % Cosmic X-ray background (~0.85) + geomagnetic cutoff modulated albedo/cosmic-ray component (~0.25*L_mean)
    L_active = L_val(~in_rad);
    if isempty(L_active), L_active = 1.2; end
    res.bg_rate_cts_cm2_s = 0.85 + 0.22 * mean(min(L_active, 4.0));
end
