function [t_out, r_out, v_out, diag_out] = orbit_propagator(r0, v0, tspan, sc_params, const, atmo, opts)
% ORBIT_PROPAGATOR High-precision numerical orbit propagator in J2000 ECI frame.
% Uses variable-order Adams-Bashforth-Moulton solver (`ode113`, RelTol=1e-9, AbsTol=1e-10).
%
% Force model (all individually toggleable for verification & ablation testing):
%   1. Earth central two-body gravity (WGS-84 / EGM2008 mu)
%   2. Zonal geopotential harmonics J2, J3, J4 (Vallado 5th Ed. Eq. 8-25)
%   3. Co-rotating atmospheric drag with live-calibrated NRLMSISE-00 density
%   4. Cannonball Solar Radiation Pressure (SRP) with conical Earth shadow
%   5. State 7: Exact Gauss-variational secular semi-major axis loss from drag work
%
% Inputs:
%   r0, v0    - Initial ECI position [m] and velocity [m/s] (3x1)
%   tspan     - Time vector from mission epoch [s]
%   sc_params - Struct with mass_wet_kg, A_drag_m2, A_srp_m2, Cd, Cr
%   const     - Constants struct
%   atmo      - Atmosphere model struct from build_atmosphere_model()
%   opts      - Optional struct: enable_J2, enable_J3, enable_J4, enable_drag,
%               enable_srp, solar_regime ('solar_min'/'solar_nom'/'solar_max')
%
% Outputs:
%   t_out, r_out (3xN), v_out (3xN)
%   diag_out  - Struct with decay_rate_m_yr, total_drag_loss_m, dv_drag_sim_ms

    if nargin < 7 || isempty(opts)
        opts = struct();
    end
    p.enable_J2    = get_opt(opts, 'enable_J2', true);
    p.enable_J3    = get_opt(opts, 'enable_J3', true);
    p.enable_J4    = get_opt(opts, 'enable_J4', true);
    p.enable_drag  = get_opt(opts, 'enable_drag', true);
    p.enable_srp   = get_opt(opts, 'enable_srp', true);
    p.solar_regime = get_opt(opts, 'solar_regime', 'solar_nom');

    p.mu          = const.mu;
    p.Re          = const.Re;
    p.J2          = const.J2;
    p.J3          = const.J3;
    p.J4          = const.J4;
    p.omegaE      = const.omegaE;
    p.P_srp       = const.P_srp;
    p.R_sun       = const.R_sun;
    p.AU          = const.AU;
    p.epoch_mjd   = const.epoch_mjd;
    p.sec_per_day = const.sec_per_day;

    p.mass        = sc_params.mass_wet_kg;
    p.B_drag      = sc_params.Cd * sc_params.A_drag_m2 / sc_params.mass_wet_kg;
    p.B_srp       = sc_params.Cr * sc_params.A_srp_m2  / sc_params.mass_wet_kg;
    p.log_rho_tbl = atmo.(p.solar_regime).log_rho;
    p.n_rho       = length(p.log_rho_tbl);

    % 7-state vector: [rx, ry, rz, vx, vy, vz, cumulative_delta_a_drag_loss]
    y0 = [r0(:); v0(:); 0.0];
    ode_opts = odeset('RelTol', 1e-9, 'AbsTol', 1e-10);

    [t_out, y_sol] = ode113(@(t, y) ode_rhs(t, y, p), tspan, y0, ode_opts);

    t_out = t_out(:)';
    r_out = y_sol(:, 1:3)';
    v_out = y_sol(:, 4:6)';

    total_time_s = t_out(end) - t_out(1);
    total_loss_m = y_sol(end, 7);
    if total_time_s > 0
        diag_out.total_drag_loss_m = total_loss_m;
        diag_out.decay_rate_m_yr   = total_loss_m * (const.days_per_yr * const.sec_per_day / total_time_s);
        r_mean = mean(sqrt(sum(r_out.^2, 1)));
        v_circ = sqrt(const.mu / r_mean);
        diag_out.dv_drag_per_yr_ms = (v_circ / (2.0 * r_mean)) * diag_out.decay_rate_m_yr;
    else
        diag_out.total_drag_loss_m = 0.0;
        diag_out.decay_rate_m_yr   = 0.0;
        diag_out.dv_drag_per_yr_ms = 0.0;
    end
end

function dydt = ode_rhs(t, y, p)
    r = y(1:3);
    v = y(4:6);
    x = r(1); y_c = r(2); z = r(3);
    r2 = x*x + y_c*y_c + z*z;
    r_mag = sqrt(r2);
    inv_r = 1.0 / r_mag;

    % 1. Central Two-Body Gravity
    a_tot = -(p.mu / (r2 * r_mag)) * r;

    % 2. Zonal Geopotential Harmonics (J2, J3, J4)
    s  = z * inv_r;
    s2 = s * s;

    if p.enable_J2
        c2 = 1.5 * p.J2 * p.mu * (p.Re^2) / (r2 * r2 * r_mag);
        f2 = 5.0 * s2 - 1.0;
        a_tot(1) = a_tot(1) + c2 * x   * f2;
        a_tot(2) = a_tot(2) + c2 * y_c * f2;
        a_tot(3) = a_tot(3) + c2 * z   * (5.0 * s2 - 3.0);
    end

    if p.enable_J3
        c3 = 0.5 * p.J3 * p.mu * (p.Re^3) / (r2 * r2 * r2 * r_mag);
        s3 = s2 * s;
        f3 = 35.0 * s3 - 15.0 * s;
        a_tot(1) = a_tot(1) + c3 * x   * f3;
        a_tot(2) = a_tot(2) + c3 * y_c * f3;
        a_tot(3) = a_tot(3) + c3 * r_mag * (35.0 * s2 * s2 - 30.0 * s2 + 3.0);
    end

    if p.enable_J4
        c4 = (5.0 / 8.0) * p.J4 * p.mu * (p.Re^4) / (r2 * r2 * r2 * r2 * r_mag);
        s4 = s2 * s2;
        f4_xy = 3.0 * (21.0 * s4 - 14.0 * s2 + 1.0);
        f4_z  = 63.0 * s4 - 70.0 * s2 + 15.0;
        a_tot(1) = a_tot(1) + c4 * x   * f4_xy;
        a_tot(2) = a_tot(2) + c4 * y_c * f4_xy;
        a_tot(3) = a_tot(3) + c4 * z   * f4_z;
    end

    % 3. Atmospheric Drag (co-rotating thermosphere + live-calibrated NRLMSISE-00)
    loss_rate_m_s = 0.0;
    if p.enable_drag
        % Approximate geodetic altitude (WGS-84 oblateness correction ~21.4 km*sin^2(lat))
        h_km = (r_mag - p.Re * (1.0 - 0.00335281 * s2)) * 1e-3;
        h_c  = max(100.0, min(1000.0, h_km));
        idx_f = (h_c - 100.0) * 0.2 + 1.0;
        i0    = floor(idx_f);
        if i0 >= p.n_rho, i0 = p.n_rho - 1; end
        if i0 < 1,        i0 = 1;           end
        rho = exp(p.log_rho_tbl(i0) + (idx_f - i0) * (p.log_rho_tbl(i0 + 1) - p.log_rho_tbl(i0)));

        v_rel = [v(1) + p.omegaE * y_c;
                 v(2) - p.omegaE * x;
                 v(3)];
        v_rel_mag = sqrt(v_rel(1)^2 + v_rel(2)^2 + v_rel(3)^2);

        a_drag = -0.5 * rho * p.B_drag * v_rel_mag * v_rel;
        a_tot  = a_tot + a_drag;

        % Gauss variational equation for secular semi-major axis loss from drag work
        eps_E = 0.5 * (v(1)^2 + v(2)^2 + v(3)^2) - p.mu * inv_r;
        if eps_E < -1e3
            a_osc = -0.5 * p.mu / eps_E;
        else
            a_osc = r_mag;
        end
        loss_rate_m_s = max(0.0, -(2.0 * a_osc * a_osc / p.mu) * (v(1)*a_drag(1) + v(2)*a_drag(2) + v(3)*a_drag(3)));
    end

    % 4. Cannonball Solar Radiation Pressure (SRP) with conical shadow factor
    if p.enable_srp
        mjd_now = p.epoch_mjd + t / p.sec_per_day;
        T_c     = (mjd_now - 51544.5) / 36525.0;
        M_s     = (357.5277233 + 35999.05034 * T_c) * (pi / 180.0);
        lam_s   = (280.460 + 36000.771 * T_c + 1.914666471 * sin(M_s) + 0.019994643 * sin(2*M_s)) * (pi / 180.0);
        eps_s   = (23.439291 - 0.0130042 * T_c) * (pi / 180.0);
        u_sun   = [cos(lam_s); cos(eps_s)*sin(lam_s); sin(eps_s)*sin(lam_s)];

        % Smooth C1 cubic Hermite conical penumbra transition (prevents ODE113 step-size chatter)
        s_proj = r(1)*u_sun(1) + r(2)*u_sun(2) + r(3)*u_sun(3);
        nu_illum = 1.0;
        if s_proj < 0.0
            d_perp = sqrt(max(0.0, r2 - s_proj*s_proj));
            dist_a = -s_proj;
            R_u = p.Re - dist_a * ((p.R_sun - p.Re) / p.AU);
            R_p = p.Re + dist_a * ((p.R_sun + p.Re) / p.AU);
            if d_perp <= R_u
                nu_illum = 0.0;
            elseif d_perp < R_p
                u_s = (d_perp - R_u) / max(R_p - R_u, 1.0);
                nu_illum = u_s * u_s * (3.0 - 2.0 * u_s); % Smooth C1 Hermite transition
            end
        end

        if nu_illum > 0.0
            a_tot = a_tot - (nu_illum * p.P_srp * p.B_srp) * u_sun;
        end
    end

    dydt = [v; a_tot; loss_rate_m_s];
end

function val = get_opt(s, field, default_val)
    if isfield(s, field)
        val = s.(field);
    else
        val = default_val;
    end
end
