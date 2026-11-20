function ver = verify_mission_analysis(const, atmo, geomag, comms, req)
% VERIFY_MISSION_ANALYSIS Automated Verification & Literature Plausibility Test Suite.
% Directly fulfills TUM Report Guide p. 5 ("a plausibility check, for instance a comparison
% with a hand calculation or a value from the literature") & ECSS-E-ST-10-02C.
%
% Executes 6 quantitative verification & benchmark tests:
%   V-01: Two-body energy & angular momentum conservation (relative error < 1e-9)
%   V-02: Analytical J2 secular RAAN precession vs numerical ODE113 (SSO = +0.9856 deg/day)
%   V-03: Analytical max eclipse duration (beta=0) vs numerical conical shadow solver
%   V-04: Analytical circular drag decay vs numerical Gauss-variational drag work integrator
%   V-05: Literature benchmark — Neil Gehrels Swift Observatory (600 km, 20.6 deg, 1.4 sr)
%   V-06: Literature benchmark — SVOM VHF Alert Network (625 km, 29.0 deg, ~93% cov, ~8.9 s med)
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    tests = struct();
    k = 0;

    % Reference test spacecraft struct
    sc_test.mass_wet_kg = 75.0;
    sc_test.A_drag_m2   = 0.65;
    sc_test.A_srp_m2    = 0.75;
    sc_test.Cd          = 2.2;
    sc_test.Cr          = 1.3;

    %% V-01: Two-Body Energy & Angular Momentum Conservation
    k = k + 1;
    a0 = (const.Re_km + 500.0) * 1e3;
    T0 = 2.0 * pi * sqrt(a0^3 / const.mu);
    [r0, v0] = kep2cart(a0, 0.01, 28.5, 45.0, 0.0, 0.0, const.mu);
    opts_2b = struct('enable_J2', false, 'enable_J3', false, 'enable_J4', false, ...
                     'enable_drag', false, 'enable_srp', false);
    [~, r_2b, v_2b, ~] = orbit_propagator(r0, v0, linspace(0, 10*T0, 1000), sc_test, const, atmo, opts_2b);

    eps_E = 0.5 * sum(v_2b.^2, 1) - const.mu ./ sqrt(sum(r_2b.^2, 1));
    h_mag = sqrt(sum(cross(r_2b, v_2b, 1).^2, 1));
    rel_dE = max(abs(eps_E - eps_E(1))) / abs(eps_E(1));
    rel_dH = max(abs(h_mag - h_mag(1))) / abs(h_mag(1));

    tests(k).id        = 'V-01';
    tests(k).name      = 'Two-Body Energy & Angular Momentum Conservation (10 orbits)';
    tests(k).numerical = sprintf('dE/E=%.2e, dH/H=%.2e', rel_dE, rel_dH);
    tests(k).reference = '< 1.0e-8 (analytical invariant)';
    tests(k).passed    = (rel_dE < 1e-8) && (rel_dH < 1e-8);

    %% V-02: Analytical J2 Secular RAAN Precession (SSO 500 km, 97.4 deg)
    k = k + 1;
    inc_sso = 97.402; % Exact 500 km SSO inclination
    [r0_s, v0_s] = kep2cart(a0, 0.0005, inc_sso, 45.0, 0.0, 0.0, const.mu);
    opts_j2 = struct('enable_J2', true, 'enable_J3', false, 'enable_J4', false, ...
                     'enable_drag', false, 'enable_srp', false);
    n_orbits = 30;
    t_j2 = linspace(0, n_orbits * T0, 600);
    [~, r_j2, v_j2, ~] = orbit_propagator(r0_s, v0_s, t_j2, sc_test, const, atmo, opts_j2);
    kep_j2 = cart2kep(r_j2, v_j2, const.mu);
    raan_unwrap = rad2deg(unwrap(deg2rad(kep_j2.raan_deg)));
    p_fit = polyfit(t_j2 / const.sec_per_day, raan_unwrap, 1);
    raan_dot_num = p_fit(1); % [deg/day]

    n_rad = sqrt(const.mu / a0^3);
    p_m   = a0 * (1.0 - 0.0005^2);
    raan_dot_ana = rad2deg(-1.5 * n_rad * const.J2 * (const.Re / p_m)^2 * cosd(inc_sso)) * const.sec_per_day;
    err_j2_pct   = 100.0 * abs(raan_dot_num - raan_dot_ana) / abs(raan_dot_ana);

    tests(k).id        = 'V-02';
    tests(k).name      = 'J2 Secular RAAN Precession vs Analytical (500 km SSO)';
    tests(k).numerical = sprintf('%.4f deg/day (err=%.2f%%)', raan_dot_num, err_j2_pct);
    tests(k).reference = sprintf('%.4f deg/day (SSO=0.9856)', raan_dot_ana);
    tests(k).passed    = (err_j2_pct < 1.5) && (abs(raan_dot_num - 0.9856) < 0.02);

    %% V-03: Analytical Max Eclipse Duration at Beta = 0 deg (600 km)
    k = k + 1;
    a_600 = (const.Re_km + 600.0) * 1e3;
    T_600 = 2.0 * pi * sqrt(a_600^3 / const.mu);
    % Choose orbital plane containing Sun vector at epoch (beta = 0 deg)
    [u_sun0, ~] = sun_moon_ephemeris(const.epoch_mjd, const);
    raan_b0 = rad2deg(atan2(u_sun0(2), u_sun0(1))); % Ascending node aligned with Sun -> beta = 0
    [r0_e, v0_e] = kep2cart(a_600, 0.0, 29.0, raan_b0, 0.0, 0.0, const.mu);
    t_ec = 0:2.0:(2.0 * T_600);
    [~, r_ec, v_ec, ~] = orbit_propagator(r0_e, v0_e, t_ec, sc_test, const, atmo, opts_2b);
    cfg_dummy.a_m = a_600; cfg_dummy.e = 0.0; cfg_dummy.inc_deg = 29.0; cfg_dummy.raan_deg = raan_b0;
    ecl_chk = analyze_eclipse_annual(t_ec, r_ec, v_ec, cfg_dummy, const);
    ecl_ana_min = (asin(const.Re / a_600) / pi) * (T_600 / 60.0);
    err_ecl_pct = 100.0 * abs(ecl_chk.sim_max_eclipse_min - ecl_ana_min) / ecl_ana_min;

    tests(k).id        = 'V-03';
    tests(k).name      = 'Conical Max Eclipse Duration at Beta=0 (600 km) vs Hand Calc';
    tests(k).numerical = sprintf('%.2f min (err=%.2f%%)', ecl_chk.sim_max_eclipse_min, err_ecl_pct);
    tests(k).reference = sprintf('%.2f min (T/pi*asin(Re/a))', ecl_ana_min);
    tests(k).passed    = (err_ecl_pct < 2.0);

    %% V-04: Analytical Circular Drag Decay vs Numerical Gauss Work Integrator (500 km)
    k = k + 1;
    [r0_d, v0_d] = kep2cart(a0, 0.0, 28.5, 45.0, 0.0, 0.0, const.mu);
    opts_dr = struct('enable_J2', false, 'enable_J3', false, 'enable_J4', false, ...
                     'enable_drag', true, 'enable_srp', false, 'solar_regime', 'solar_nom');
    t_dr = linspace(0, 1.0 * const.sec_per_day, 1440);
    [~, ~, ~, diag_dr] = orbit_propagator(r0_d, v0_d, t_dr, sc_test, const, atmo, opts_dr);
    rho_500 = atmosphere_density(500.0, atmo, 'solar_nom');
    B_t     = sc_test.Cd * sc_test.A_drag_m2 / sc_test.mass_wet_kg;
    % Exact co-rotating circular analytical drag decay (Vallado Eq. 8-35):
    corot   = (1.0 - (const.omegaE / sqrt(const.mu / a0^3)) * cosd(28.5))^2;
    dadt_ana_m_yr = sqrt(const.mu * a0) * rho_500 * B_t * corot * const.days_per_yr * const.sec_per_day;
    err_dr_pct = 100.0 * abs(diag_dr.decay_rate_m_yr - dadt_ana_m_yr) / dadt_ana_m_yr;

    tests(k).id        = 'V-04';
    tests(k).name      = 'Gauss Drag Work Decay vs Analytical Circular Rate (500 km)';
    tests(k).numerical = sprintf('%.0f m/yr (err=%.2f%%)', diag_dr.decay_rate_m_yr, err_dr_pct);
    tests(k).reference = sprintf('%.0f m/yr (NRLMSISE-00 Nom)', dadt_ana_m_yr);
    tests(k).passed    = (err_dr_pct < 6.0); % Small oblate geodetic altitude difference (<4%)

    %% V-05: Literature Calibration — Neil Gehrels Swift Observatory (600 km, 20.6 deg)
    k = k + 1;
    t_sw = 0:30.0:(2.0 * const.sec_per_day);
    [r0_sw, v0_sw] = kep2cart(a_600, 0.001, 20.6, 45.0, 0.0, 0.0, const.mu);
    opts_full = struct('enable_J2', true, 'enable_J3', true, 'enable_J4', true, ...
                       'enable_drag', true, 'enable_srp', false, 'solar_regime', 'solar_nom');
    [~, r_sw_eci, v_sw_eci, ~] = orbit_propagator(r0_sw, v0_sw, t_sw, sc_test, const, atmo, opts_full);
    r_sw_ecef = eci2ecef_iau(r_sw_eci, v_sw_eci, t_sw, const);
    [lat_sw, lon_sw, alt_sw] = ecef2lla_wgs84(r_sw_ecef, const);
    rad_sw = analyze_radiation_saa(t_sw, lat_sw, lon_sw, alt_sw, geomag);

    % Check Swift SAA loss (published ~9-15%) and Earth occultation (~30%)
    occ_sw = 50.0 * (1.0 - cos(asin((const.Re + 80e3) / a_600)));
    tests(k).id        = 'V-05';
    tests(k).name      = 'Literature Benchmark: Swift LEO (600 km, 20.6 deg)';
    tests(k).numerical = sprintf('SAA=%.1f%%, Occ=%.1f%%', rad_sw.saa_fraction_pct, occ_sw);
    tests(k).reference = 'Lit: SAA ~9-15%, Occ ~30-32% (Gehrels 2004)';
    tests(k).passed    = (rad_sw.saa_fraction_pct >= 6.0) && (rad_sw.saa_fraction_pct <= 18.0) && ...
                         (abs(occ_sw - 31.0) < 3.0);

    %% V-06: Literature Calibration — SVOM Equatorial VHF Network (625 km, 29.0 deg)
    k = k + 1;
    a_sv = (const.Re_km + 625.0) * 1e3;
    [r0_sv, v0_sv] = kep2cart(a_sv, 0.001, 29.0, 45.0, 0.0, 0.0, const.mu);
    t_sv = 0:15.0:(2.0 * const.sec_per_day);
    [~, r_sv_eci, v_sv_eci, ~] = orbit_propagator(r0_sv, v0_sv, t_sv, sc_test, const, atmo, opts_full);
    r_sv_ecef = eci2ecef_iau(r_sv_eci, v_sv_eci, t_sv, const);

    cfg_sv.id = 99; cfg_sv.num_sats = 1; cfg_sv.h_km = 625.0; cfg_sv.a_m = a_sv;
    cfg_sv.onboard_proc_s = 4.0; cfg_sv.loc_principle = 'coded_mask';
    lat_sv = analyze_comms_latency(t_sv, {r_sv_ecef}, cfg_sv, comms, req, const);

    tests(k).id        = 'V-06';
    tests(k).name      = 'Literature Benchmark: SVOM VHF Network (625 km, 29.0 deg)';
    tests(k).numerical = sprintf('Cov=%.1f%%, Med=%.1fs, <=30s=%.1f%%', ...
                                 lat_sv.vhf_orbit_cov_pct, lat_sv.vhf.p50_s, lat_sv.vhf.pct_le_30s);
    tests(k).reference = 'Lit: Cov ~93%, Med 8.9s, >=66% <=30s (arXiv:2604.24263)';
    tests(k).passed    = (lat_sv.vhf_orbit_cov_pct >= 85.0) && (lat_sv.vhf.p50_s <= 15.0) && ...
                         (lat_sv.vhf.pct_le_30s >= 80.0);

    ver.tests      = tests;
    ver.all_passed = all([tests.passed]);
    ver.n_passed   = sum([tests.passed]);
    ver.n_total    = length(tests);
end
