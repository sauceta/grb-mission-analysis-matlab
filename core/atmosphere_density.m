function rho = atmosphere_density(h_km, atmo, regime)
% ATMOSPHERE_DENSITY Fast log-linear interpolation of live-calibrated NRLMSISE-00 profiles.
%
% Inputs:
%   h_km   - Geodetic altitude [km] (scalar or array)
%   atmo   - Pre-built atmosphere struct from build_atmosphere_model()
%   regime - 'solar_min', 'solar_nom' (default), or 'solar_max'
%
% Output:
%   rho    - Atmospheric mass density [kg/m^3]

    if nargin < 3 || isempty(regime)
        regime = 'solar_nom';
    end

    orig_size   = size(h_km);
    h_clamped   = max(100.0, min(1000.0, h_km(:)));
    log_rho_tbl = atmo.(regime).log_rho(:);

    % Direct uniform-grid index interpolation (5 km spacing -> ~20x faster than interp1 inside ODE)
    idx_f = (h_clamped - 100.0) * 0.2 + 1.0;
    i0    = floor(idx_f);
    i0    = max(1, min(length(log_rho_tbl) - 1, i0));
    frac  = idx_f - i0;

    log_rho = log_rho_tbl(i0) + frac .* (log_rho_tbl(i0 + 1) - log_rho_tbl(i0));
    rho     = reshape(exp(log_rho), orig_size);
end
