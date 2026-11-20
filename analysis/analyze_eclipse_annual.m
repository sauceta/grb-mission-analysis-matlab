function res = analyze_eclipse_annual(t_sec, r_eci, v_eci, cfg, const)
% ANALYZE_ECLIPSE_ANNUAL Conical shadow (umbra/penumbra) & 365-day solar beta envelope.
% Provides BOTH:
%   1. High-resolution conical umbra/penumbra state along the propagated orbit (5 days)
%   2. Full 365-day nodal-precession solar beta angle & eclipse duration evolution
%      to accurately deliver Worst Cold Case (max eclipse at beta=0) and Worst Hot Case
%      (min eclipse / full sun at |beta|_max) to Power and Simscape Thermal subsystems!
%
% Reference: Vallado 5th Ed. Section 5.3 (Conical Shadow Model) & Wertz SMAD Ch. 5.
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    %% 1. High-Resolution Conical Shadow on Propagated Trajectory
    N = length(t_sec);
    mjd_vec = const.epoch_mjd + t_sec / const.sec_per_day;
    [u_sun, r_sun_m] = sun_moon_ephemeris(mjd_vec, const);
    r_sun_mag = sqrt(sum(r_sun_m.^2, 1));

    % Vectorized conical umbra & penumbra geometry (Montenbruck & Gill Eq. 3.79)
    r_mag  = sqrt(sum(r_eci.^2, 1));
    s_proj = sum(r_eci .* u_sun, 1); % Projection along Sun direction
    d_perp = sqrt(max(0.0, r_mag.^2 - s_proj.^2));

    % Umbra and penumbra cone half-angles
    alpha_u = asin((const.R_sun - const.Re) ./ r_sun_mag); % Umbra taper angle
    alpha_p = asin((const.R_sun + const.Re) ./ r_sun_mag); % Penumbra expansion angle

    % Shadow cone radii at spacecraft anti-solar distance |s_proj|
    dist_anti = max(0.0, -s_proj);
    R_u = const.Re - dist_anti .* tan(alpha_u);
    R_p = const.Re + dist_anti .* tan(alpha_p);

    in_umbra    = (s_proj < 0.0) & (d_perp < R_u);
    in_penumbra = (s_proj < 0.0) & (d_perp >= R_u) & (d_perp < R_p);
    in_eclipse  = in_umbra | in_penumbra;

    % Solar beta angle along propagated orbit
    h_vec = cross(r_eci, v_eci, 1);
    u_h   = h_vec ./ sqrt(sum(h_vec.^2, 1));
    beta_sim_deg = rad2deg(asin(max(-1.0, min(1.0, sum(u_h .* u_sun, 1)))));

    res.t_sim_sec       = t_sec;
    res.in_umbra        = in_umbra;
    res.in_penumbra     = in_penumbra;
    res.in_eclipse      = in_eclipse;
    res.beta_sim_deg    = beta_sim_deg;
    res.sim_sunlight_pct = 100.0 * (1.0 - mean(in_eclipse));

    % Measure eclipse durations in propagated window
    d_ec   = diff([false, in_eclipse, false]);
    starts = find(d_ec == 1);
    ends   = find(d_ec == -1) - 1;
    dt_sec = t_sec(2) - t_sec(1);
    if ~isempty(starts)
        dur_min = (ends - starts + 1) * dt_sec / 60.0;
        res.sim_max_eclipse_min  = max(dur_min);
        res.sim_mean_eclipse_min = mean(dur_min);
    else
        res.sim_max_eclipse_min  = 0.0;
        res.sim_mean_eclipse_min = 0.0;
    end

    %% 2. Full 365-Day Solar Beta & Worst-Case Eclipse Envelope (Power & Thermal Boundary)
    days_yr = 0:0.5:365.0; % Half-day resolution over full year
    N_yr    = length(days_yr);
    mjd_yr  = const.epoch_mjd + days_yr;
    [u_sun_yr, ~] = sun_moon_ephemeris(mjd_yr, const);

    % Analytical J2 secular RAAN precession rate [rad/s]
    a_m   = cfg.a_m;
    e_val = cfg.e;
    inc   = deg2rad(cfg.inc_deg);
    n_rad = sqrt(const.mu / (a_m^3));
    T_orb_min = (2.0 * pi / n_rad) / 60.0;
    p_m   = a_m * (1.0 - e_val^2);
    raan_dot_rad_s = -1.5 * n_rad * const.J2 * ((const.Re / p_m)^2) * cos(inc);

    raan_yr = deg2rad(cfg.raan_deg(1)) + raan_dot_rad_s * (days_yr * const.sec_per_day);

    % Orbit normal unit vector in ECI: u_h = [sin(i)*sin(O); -sin(i)*cos(O); cos(i)]
    u_h_yr = [sin(inc) * sin(raan_yr);
             -sin(inc) * cos(raan_yr);
              cos(inc) * ones(1, N_yr)];

    beta_yr_rad = asin(max(-1.0, min(1.0, sum(u_h_yr .* u_sun_yr, 1))));
    beta_yr_deg = rad2deg(beta_yr_rad);

    % Critical beta angle for cylindrical/conical Earth shadow boundary
    % Include solar angular radius (+0.266 deg) for penumbra onset
    beta_crit_rad = asin(const.Re / a_m);
    beta_crit_deg = rad2deg(beta_crit_rad);

    % Exact circular-orbit eclipse fraction f_E(beta) (Wertz SMAD Eq. 5-8):
    % f_E = (1/pi) * acos( sqrt(h^2 + 2*Re*h) / (a * cos(beta)) ) for |beta| < beta_crit
    ecl_frac_yr = zeros(1, N_yr);
    has_ecl = abs(beta_yr_rad) < beta_crit_rad;
    arg_cos = sqrt(max(0.0, a_m^2 - const.Re^2)) ./ (a_m * cos(beta_yr_rad(has_ecl)));
    arg_cos = max(-1.0, min(1.0, arg_cos));
    ecl_frac_yr(has_ecl) = acos(arg_cos) / pi;

    ecl_dur_yr_min = ecl_frac_yr * T_orb_min;

    res.days_yr             = days_yr;
    res.beta_yr_deg         = beta_yr_deg;
    res.beta_crit_deg       = beta_crit_deg;
    res.ecl_dur_yr_min      = ecl_dur_yr_min;
    res.ecl_frac_yr_pct     = ecl_frac_yr * 100.0;
    res.T_orbit_min         = T_orb_min;
    res.raan_dot_deg_day    = rad2deg(raan_dot_rad_s) * const.sec_per_day;

    % Worst-case Power & Thermal design drivers
    res.worst_cold_eclipse_min = max(ecl_dur_yr_min);      % Max eclipse (beta -> 0)
    res.worst_hot_eclipse_min  = min(ecl_dur_yr_min);      % Min eclipse (|beta| -> max)
    res.beta_max_abs_deg       = max(abs(beta_yr_deg));
    res.mean_eclipse_yr_min    = mean(ecl_dur_yr_min);
    res.mean_sunlight_yr_pct   = 100.0 * (1.0 - mean(ecl_frac_yr));
    res.full_sun_days_per_yr   = sum(~has_ecl) * 0.5;      % Days with zero eclipse
end
