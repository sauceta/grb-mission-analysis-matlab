function atmo = build_atmosphere_model(const)
% BUILD_ATMOSPHERE_MODEL Generates live-calibrated NRLMSISE-00 atmospheric density profiles.
% Queries MATLAB Aerospace Toolbox `atmosnrlmsise00` across three ECSS-E-ST-10-04C
% solar-geomagnetic bounding regimes:
%   - solar_min : F10.7 =  70 sfu, Ap =  5  (worst-case slow decay -> ESA 5-yr lifetime rule)
%   - solar_nom : F10.7 = 140 sfu, Ap = 15  (nominal Solar Cycle 25/26 transition ~2028-2031)
%   - solar_max : F10.7 = 220 sfu, Ap = 30  (worst-case high drag  -> station-keeping Delta-V)
%
% Profiles are averaged over latitude (-30..+30 deg) and local solar time (diurnal cycle)
% to represent true orbit-averaged thermospheric density, then stored as log-density
% splines for ultra-fast evaluation inside ODE113/ODE89 propagation.
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    if nargin < 1
        const = constants();
    end

    h_grid_km = (100:5:1000)';
    N_h = length(h_grid_km);
    atmo.h_grid_km = h_grid_km;

    % ECSS-E-ST-10-04C bounding solar activity definitions
    regimes = {
        'solar_min',  70.0,  5.0;
        'solar_nom', 140.0, 15.0;
        'solar_max', 220.0, 30.0
    };

    use_nrlmsise = (exist('atmosnrlmsise00', 'file') == 2);
    atmo.source = 'NRLMSISE-00 (Aerospace Toolbox)';

    if use_nrlmsise
        % Average across 4 latitudes & 4 diurnal local times (16 samples per altitude)
        sample_lats = [-25, -8, 8, 25];
        sample_lons = [-135, -45, 45, 135]; % spans 00:00, 06:00, 12:00, 18:00 LST
        year_val = const.epoch_utc(1);
        doy_val  = 152; % June 1
        ut_sec   = 43200.0; % 12:00 UTC

        [H_m, LAT_m, LON_m] = ndgrid(h_grid_km * 1e3, sample_lats, sample_lons);
        h_vec   = H_m(:);
        lat_vec = LAT_m(:);
        lon_vec = LON_m(:);
        M = numel(h_vec);

        yr_vec  = year_val * ones(M, 1);
        doy_vec = doy_val  * ones(M, 1);
        ut_vec  = ut_sec   * ones(M, 1);

        for r = 1:size(regimes, 1)
            rname = regimes{r, 1};
            f107  = regimes{r, 2};
            ap    = regimes{r, 3};

            [~, rho_all] = atmosnrlmsise00(h_vec, lat_vec, lon_vec, yr_vec, doy_vec, ut_vec, ...
                                           f107 * ones(M, 1), f107 * ones(M, 1), ap * ones(M, 1));
            rho_total = reshape(rho_all(:, 6), N_h, numel(sample_lats), numel(sample_lons));
            rho_mean  = mean(rho_total, [2, 3]); % Diurnal & latitudinal orbit-average [kg/m^3]

            atmo.(rname).f107    = f107;
            atmo.(rname).ap      = ap;
            atmo.(rname).rho     = max(rho_mean, 1e-22);
            atmo.(rname).log_rho = log(atmo.(rname).rho);
        end
    else
        % Fallback: Vallado Table 8-4 exponential atmosphere scaled by solar regime
        atmo.source = 'Vallado Exponential Fallback';
        base_tbl = [
            100, 5.297e-7,   5.877;
            150, 2.070e-9,  22.523;
            200, 2.789e-10, 37.105;
            300, 2.418e-11, 53.628;
            400, 3.725e-12, 58.515;
            500, 6.967e-13, 63.822;
            600, 1.454e-13, 71.835;
            700, 3.270e-14, 83.210;
            800, 7.860e-15, 99.200;
           1000, 6.000e-16, 150.00
        ];
        rho_base = exp(interp1(base_tbl(:, 1), log(base_tbl(:, 2)), h_grid_km, 'pchip', 'extrap'));
        scale_map = [0.45, 1.00, 2.35]; % Min / Nom / Max approximations
        for r = 1:size(regimes, 1)
            rname = regimes{r, 1};
            atmo.(rname).f107    = regimes{r, 2};
            atmo.(rname).ap      = regimes{r, 3};
            atmo.(rname).rho     = max(rho_base * scale_map(r), 1e-22);
            atmo.(rname).log_rho = log(atmo.(rname).rho);
        end
    end
end
