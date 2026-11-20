function [r, v] = kep2cart(a, e, inc_deg, raan_deg, omega_deg, nu_deg, mu)
% KEP2CART Converts classical Keplerian orbital elements to ECI Cartesian state.
% Reference: Vallado, "Fundamentals of Astrodynamics and Applications", 5th Ed., Algorithm 10.
%
% Inputs:
%   a         - Semi-major axis [m]
%   e         - Eccentricity [-]
%   inc_deg   - Inclination [deg]
%   raan_deg  - Right Ascension of Ascending Node [deg]
%   omega_deg - Argument of perigee [deg]
%   nu_deg    - True anomaly [deg]
%   mu        - Gravitational parameter [m^3/s^2] (optional)
%
% Outputs:
%   r         - Position vector in ECI [m] (3x1)
%   v         - Velocity vector in ECI [m/s] (3x1)

    if nargin < 7
        const = constants();
        mu = const.mu;
    end

    inc   = deg2rad(inc_deg);
    raan  = deg2rad(raan_deg);
    omega = deg2rad(omega_deg);
    nu    = deg2rad(nu_deg);

    p      = a * (1.0 - e^2);
    r_norm = p / (1.0 + e * cos(nu));

    % Perifocal (PQW) state
    r_pqw = [r_norm * cos(nu);
             r_norm * sin(nu);
             0.0];
    v_pqw = [-sqrt(mu / p) * sin(nu);
              sqrt(mu / p) * (e + cos(nu));
              0.0];

    % Direct 3-1-3 DCM (PQW -> ECI)
    cO = cos(raan);  sO = sin(raan);
    ci = cos(inc);   si = sin(inc);
    cw = cos(omega); sw = sin(omega);

    Q = [cO*cw - sO*sw*ci, -cO*sw - sO*cw*ci,  sO*si;
         sO*cw + cO*sw*ci, -sO*sw + cO*cw*ci, -cO*si;
         sw*si,             cw*si,             ci];

    r = Q * r_pqw;
    v = Q * v_pqw;
end
