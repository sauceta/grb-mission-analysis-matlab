function [u_sun, r_sun_m, u_moon, r_moon_m] = sun_moon_ephemeris(mjd_vec, const)
% SUN_MOON_EPHEMERIS Vectorized analytical ECI (J2000) ephemerides for Sun & Moon.
% References:
%   - Vallado, "Fundamentals of Astrodynamics and Applications", 5th Ed.:
%     Algorithm 29 (Sun, <0.01 deg accuracy) & Algorithm 31 (Moon, <0.3 deg accuracy).
% Used for conical shadow geometry, SRP force, and OPS-060 Sun/Moon exclusion checks.
%
% Input:
%   mjd_vec  - Modified Julian Date row/col vector (1xN)
%   const    - Constants struct (optional)
%
% Outputs:
%   u_sun    - Unit vector Earth -> Sun in ECI (3xN)
%   r_sun_m  - Position vector Earth -> Sun in ECI [m] (3xN)
%   u_moon   - Unit vector Earth -> Moon in ECI (3xN)
%   r_moon_m - Position vector Earth -> Moon in ECI [m] (3xN)

    if nargin < 2
        const = constants();
    end

    mjd = mjd_vec(:)'; % 1xN
    T   = (mjd - 51544.5) / 36525.0; % Julian centuries since J2000.0

    % Mean obliquity of the ecliptic [rad]
    eps_rad = deg2rad(23.439291 - 0.0130042 .* T);
    cos_eps = cos(eps_rad);
    sin_eps = sin(eps_rad);

    %% 1. Sun Position (Vallado Algorithm 29)
    lam_M   = mod(280.460 + 36000.771 .* T, 360.0);
    M_sun   = deg2rad(mod(357.5277233 + 35999.05034 .* T, 360.0));
    lam_ecl = deg2rad(lam_M + 1.914666471 .* sin(M_sun) + 0.019994643 .* sin(2.0 * M_sun));

    r_sun_au = 1.000140612 - 0.016708617 .* cos(M_sun) - 0.000139589 .* cos(2.0 * M_sun);

    u_sun = [cos(lam_ecl);
             cos_eps .* sin(lam_ecl);
             sin_eps .* sin(lam_ecl)];
    u_sun = u_sun ./ sqrt(sum(u_sun.^2, 1));
    r_sun_m = u_sun .* (r_sun_au * const.AU);

    %% 2. Moon Position (Vallado Algorithm 31)
    if nargout > 2
        % Ecliptic longitude, latitude, horizontal parallax [deg]
        lam_m = 218.32 + 481267.8813 .* T ...
              + 6.29 .* sind(134.9 + 477198.85 .* T) ...
              - 1.27 .* sind(259.2 - 413335.38 .* T) ...
              + 0.66 .* sind(235.7 + 890534.23 .* T) ...
              + 0.21 .* sind(269.9 + 954397.70 .* T) ...
              - 0.19 .* sind(357.5 +  35999.05 .* T) ...
              - 0.11 .* sind(186.6 + 966404.05 .* T);

        phi_m = 5.13 .* sind( 93.3 + 483202.03 .* T) ...
              + 0.28 .* sind(228.2 + 960400.87 .* T) ...
              - 0.28 .* sind(318.3 +   6003.18 .* T) ...
              - 0.17 .* sind(217.6 - 407332.20 .* T);

        hp_deg = 0.9508 ...
               + 0.0518 .* cosd(134.9 + 477198.85 .* T) ...
               + 0.0095 .* cosd(259.2 - 413335.38 .* T) ...
               + 0.0078 .* cosd(235.7 + 890534.23 .* T) ...
               + 0.0028 .* cosd(269.9 + 954397.70 .* T);

        r_moon_mag = const.Re ./ sind(hp_deg);

        c_phi = cosd(phi_m); s_phi = sind(phi_m);
        c_lam = cosd(lam_m); s_lam = sind(lam_m);

        u_moon = [c_phi .* c_lam;
                  cos_eps .* c_phi .* s_lam - sin_eps .* s_phi;
                  sin_eps .* c_phi .* s_lam + cos_eps .* s_phi];
        u_moon = u_moon ./ sqrt(sum(u_moon.^2, 1));
        r_moon_m = u_moon .* r_moon_mag;
    end
end
