function kep = cart2kep(r_eci, v_eci, mu)
% CART2KEP Vectorized conversion from ECI Cartesian state to classical Keplerian elements.
% Reference: Vallado, "Fundamentals of Astrodynamics and Applications", 5th Ed., Algorithm 9.
%
% Inputs:
%   r_eci - Position matrix in ECI [m] (3xN)
%   v_eci - Velocity matrix in ECI [m/s] (3xN)
%   mu    - Gravitational parameter [m^3/s^2] (optional)
%
% Output struct kep (each field 1xN):
%   a_m, e, inc_deg, raan_deg, omega_deg, nu_deg

    if nargin < 3
        const = constants();
        mu = const.mu;
    end

    r_mag = sqrt(sum(r_eci.^2, 1));
    v_mag = sqrt(sum(v_eci.^2, 1));

    h_vec = cross(r_eci, v_eci, 1);
    h_mag = sqrt(sum(h_vec.^2, 1));

    % Node vector n = k x h = [-hy; hx; 0]
    n_vec = [-h_vec(2, :); h_vec(1, :); zeros(1, size(r_eci, 2))];
    n_mag = sqrt(sum(n_vec.^2, 1));

    % Eccentricity vector
    rdotv = sum(r_eci .* v_eci, 1);
    e_vec = ((v_mag.^2 - mu ./ r_mag) .* r_eci - rdotv .* v_eci) ./ mu;
    e_mag = sqrt(sum(e_vec.^2, 1));

    % Specific mechanical energy & semi-major axis
    eps_E = 0.5 * v_mag.^2 - mu ./ r_mag;
    a_m   = -mu ./ (2.0 * eps_E);

    % Inclination
    inc_rad = acos(max(-1.0, min(1.0, h_vec(3, :) ./ h_mag)));

    % RAAN
    raan_rad = zeros(size(r_mag));
    valid_n  = n_mag > 1e-10;
    cos_O    = max(-1.0, min(1.0, n_vec(1, valid_n) ./ n_mag(valid_n)));
    raan_rad(valid_n) = acos(cos_O);
    neg_ny   = valid_n & (n_vec(2, :) < 0);
    raan_rad(neg_ny)  = 2*pi - raan_rad(neg_ny);

    % Argument of perigee
    omega_rad = zeros(size(r_mag));
    valid_ne  = valid_n & (e_mag > 1e-9);
    ndote     = sum(n_vec(:, valid_ne) .* e_vec(:, valid_ne), 1);
    omega_rad(valid_ne) = acos(max(-1.0, min(1.0, ndote ./ (n_mag(valid_ne) .* e_mag(valid_ne)))));
    neg_ez    = valid_ne & (e_vec(3, :) < 0);
    omega_rad(neg_ez) = 2*pi - omega_rad(neg_ez);

    % True anomaly
    nu_rad = zeros(size(r_mag));
    valid_e = e_mag > 1e-9;
    edotr   = sum(e_vec(:, valid_e) .* r_eci(:, valid_e), 1);
    nu_rad(valid_e) = acos(max(-1.0, min(1.0, edotr ./ (e_mag(valid_e) .* r_mag(valid_e)))));
    neg_rv  = valid_e & (rdotv < 0);
    nu_rad(neg_rv) = 2*pi - nu_rad(neg_rv);

    kep.a_m       = a_m;
    kep.e         = e_mag;
    kep.inc_deg   = rad2deg(inc_rad);
    kep.raan_deg  = rad2deg(raan_rad);
    kep.omega_deg = rad2deg(omega_rad);
    kep.nu_deg    = rad2deg(nu_rad);
end
