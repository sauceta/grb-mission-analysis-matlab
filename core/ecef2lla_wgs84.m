function [lat_deg, lon_deg, alt_m] = ecef2lla_wgs84(r_ecef, const)
% ECEF2LLA_WGS84 Fully vectorized Bowring closed-form ECEF to WGS-84 geodetic LLA.
% Accuracy < 1 mm across all LEO altitudes.
%
% Input:
%   r_ecef  - Position in ECEF [m] (3xN)
%   const   - Constants struct (optional)
%
% Outputs (each 1xN):
%   lat_deg - Geodetic latitude [deg] (-90 to +90)
%   lon_deg - Geodetic longitude [deg] (-180 to +180)
%   alt_m   - Geodetic altitude above WGS-84 ellipsoid [m]

    if nargin < 2
        const = constants();
    end

    a        = const.Re;
    f        = const.f_earth;
    b        = a * (1.0 - f);
    e2       = const.e_earth^2;
    e_prime2 = (a^2 - b^2) / (b^2);

    x = r_ecef(1, :);
    y = r_ecef(2, :);
    z = r_ecef(3, :);

    p       = sqrt(x.^2 + y.^2);
    lon_deg = rad2deg(atan2(y, x));

    theta   = atan2(z * a, max(p, 1e-9) * b);
    sin_t   = sin(theta);
    cos_t   = cos(theta);

    lat_rad = atan2(z + e_prime2 * b .* (sin_t.^3), ...
                    p - e2 * a .* (cos_t.^3));
    sin_lat = sin(lat_rad);
    cos_lat = cos(lat_rad);

    N_phi   = a ./ sqrt(1.0 - e2 .* (sin_lat.^2));

    % Handle near-polar points stably without dividing by cos(90 deg)
    polar_mask = abs(lat_rad) > deg2rad(89.0);
    alt_m = zeros(size(p));
    alt_m(~polar_mask) = p(~polar_mask) ./ cos_lat(~polar_mask) - N_phi(~polar_mask);
    alt_m(polar_mask)  = abs(z(polar_mask)) ./ max(abs(sin_lat(polar_mask)), 1e-9) ...
                         - N_phi(polar_mask) * (1.0 - e2);

    lat_deg = rad2deg(lat_rad);
end
