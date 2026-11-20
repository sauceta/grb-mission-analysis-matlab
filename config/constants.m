function const = constants()
% CONSTANTS Physical, astrodynamic, environmental, and ECSS standards constants.
% References:
%   [1] Vallado, "Fundamentals of Astrodynamics and Applications", 5th Ed. (2022)
%   [2] NIMA WGS-84 Technical Report TR8350.2 & EGM2008 Geopotential Model
%   [3] IAU 2000/2006 Resolutions & ECSS-E-ST-10-04C Space Environment
%   [4] ECSS-M-ST-10C / ECSS-E-ST-32-10C Margin Policies
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    % Earth gravitational parameter & EGM2008 zonal harmonics
    const.mu        = 3.986004418e14;      % Earth GM [m^3/s^2]
    const.mu_km     = 398600.4418;         % Earth GM [km^3/s^2]
    const.J2        =  1.08262668355e-3;   % Zonal harmonic J2 [-]
    const.J3        = -2.53265648533e-6;   % Zonal harmonic J3 [-]
    const.J4        = -1.61962159137e-6;   % Zonal harmonic J4 [-]

    % WGS-84 ellipsoid & rotation
    const.Re        = 6378137.0;           % Earth equatorial radius [m]
    const.Re_km     = 6378.137;            % Earth equatorial radius [km]
    const.Re_mean   = 6371.2e3;            % IGRF spherical reference radius [m]
    const.f_earth   = 1.0 / 298.257223563; % Flattening [-]
    const.e_earth   = sqrt(2*const.f_earth - const.f_earth^2); % First eccentricity
    const.omegaE    = 7.2921150e-5;        % Earth sidereal rotation rate [rad/s]

    % Solar, lunar & physical constants
    const.c         = 299792458.0;         % Speed of light [m/s]
    const.k_B       = 1.380649e-23;        % Boltzmann constant [J/K]
    const.g0        = 9.80665;             % Standard gravity [m/s^2]
    const.AU        = 1.495978707e11;      % Astronomical Unit [m]
    const.R_sun     = 6.957e8;             % Solar photospheric radius [m]
    const.R_moon    = 1.7374e6;            % Lunar mean radius [m]
    const.SolarFlux = 1361.0;              % Total Solar Irradiance at 1 AU [W/m^2]
    const.P_srp     = const.SolarFlux / const.c; % Solar radiation pressure [N/m^2]
    const.eps_obliq = 23.439291;           % Mean obliquity of ecliptic J2000 [deg]

    % Time & mission epoch (nominal post-Swift launch window: 01-Jun-2028 00:00:00 UTC)
    const.sec_per_day  = 86400.0;
    const.days_per_yr  = 365.25;
    const.epoch_utc    = [2028, 6, 1, 0, 0, 0];
    const.epoch_mjd    = 61923.0;          % Modified Julian Date for 2028-06-01 00:00 UTC
    const.epoch_jd     = 2461923.5;        % Julian Date for 2028-06-01 00:00 UTC
    const.epoch_decyear = 2028.416;        % Decimal year for IGRF-14 & NRLMSISE-00

    % ECSS-E-ST-10C / ECSS-E-ST-32-10C Design Margins
    const.dv_margin_frac    = 0.10;        % +10% Delta-V maneuver margin (Phase A/B)
    const.prop_residual_frac = 0.02;       % +2% unusable residual & trapped propellant
    const.link_margin_req_dB = 3.0;        % Minimum RF link margin [dB]

    % Official TUM Corporate & Academic Visual Palette (matched to SRR.tex)
    const.colors.TUMBlue   = [0.000, 0.396, 0.741]; % #0065BD
    const.colors.TUMDark   = [0.000, 0.322, 0.576]; % #005293
    const.colors.TUMNavy   = [0.000, 0.200, 0.349]; % #003359
    const.colors.TUMLight  = [0.596, 0.776, 0.918]; % #98C6EA
    const.colors.TUMOrange = [0.788, 0.318, 0.051]; % #C9510D
    const.colors.TUMGreen  = [0.388, 0.600, 0.165]; % #63992A
    const.colors.TUMGold   = [0.850, 0.600, 0.050];
    const.colors.TUMPurple = [0.460, 0.220, 0.580];
    const.colors.TUMGray   = [0.400, 0.455, 0.525]; % #647486
    const.colors.TUMRed    = [0.780, 0.140, 0.140];
end
