function archs = get_architecture_configs(const)
% GET_ARCHITECTURE_CONFIGS Defines the 6 candidate GRB mission architectures.
% Directly aligns with:
%   - SRR.tex Sections 1.3 & 1.4 (SmallSat <=80 kg, <$20M envelope vs flagship & constellation)
%   - GRB Alert Mission Design.pptx Slide 20 ("Four ways to localize a burst")
%   - GRB_mission_analysis.xlsx (70 requirements including ARC-010..070)
%
% Architectures:
%   1: Compact Coded-Mask SmallSat       (SRR Baseline Candidate — 75 kg, 500 km, 28.5 deg)
%   2: Agile Coded-Mask Monolith         (Flagship Reference — SVOM/Swift, 850 kg, 600 km, 29.0 deg)
%   3: Timing-Triangulation Constellation(HERMES/CAMELOT — 6x 24 kg in 2 planes, 520 km, 28.5 deg)
%   4: Soft X-Ray Lobster-Eye Imager     (Einstein Probe WXT — 450 kg, 550 km, 29.0 deg)
%   5: All-Sky Count-Rate Ratio Monitor  (Fermi GBM/GECAM — 2x 150 kg, 550 km, 29.0 deg)
%   6: Polar SSO SmallSat Reference      (Controlled Orbit Comparison — Arch 1 in 500 km, 97.4 deg SSO)
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    if nargin < 1
        const = constants();
    end

    %% ========================================================================
    % ARCH 1: COMPACT CODED-MASK SMALLSAT (SRR Target Concept)
    %% ========================================================================
    a(1).id                 = 1;
    a(1).code               = 'ARCH-1';
    a(1).name               = 'Compact Coded-Mask SmallSat (SRR Candidate)';
    a(1).short_name         = 'Coded-Mask SmallSat';
    a(1).archetype          = 'Scaled SVOM-ECLAIRs / Gamow-Mini';
    a(1).num_sats           = 1;
    a(1).num_planes         = 1;
    a(1).sats_per_plane     = 1;

    % Orbit (ENV-050: circular LEO i <= 30 deg; 535 km selected from 2D Orbit Trade Corridor
    % to minimize Solar-Max drag makeup while keeping VHF coverage >= 90% and low perigee disposal dV)
    a(1).h_km               = 535.0;
    a(1).a_m                = (const.Re_km + a(1).h_km) * 1e3;
    a(1).e                  = 0.0005;
    a(1).inc_deg            = 28.5;
    a(1).raan_deg           = [45.0];
    a(1).omega_deg          = 0.0;
    a(1).nu_deg             = [0.0];

    % Spacecraft SWaP & Ballistics (SRR.tex: <= 80 kg SmallSat, <= 25 kg payload)
    a(1).mass_wet_kg        = 75.0;
    a(1).mass_payload_kg    = 22.0;    % Compact CdTe/CZT detector + W/Ta graded mask + shield
    a(1).mass_total_kg      = 75.0;
    a(1).power_payload_W    = 22.0;
    a(1).power_bus_avg_W    = 65.0;
    a(1).A_drag_m2          = 0.65;    % Deployed solar panels + compact 0.5x0.5x0.6 m bus
    a(1).A_srp_m2           = 0.75;
    a(1).Cd                 = 2.2;
    a(1).Cr                 = 1.3;
    a(1).Isp_s              = 220.0;   % Green monopropellant (ADN/LMP-103S)
    a(1).prop_type          = 'Green Monopropellant (LMP-103S)';

    % Instrument Physics & Localization Model
    a(1).loc_principle      = 'coded_mask';
    a(1).pointing_law       = 'anti_solar'; % B1-like anti-solar/zenith-biased pointing
    a(1).fov_sr             = 2.0;          % Half-angle ~47.1 deg (ECLAIRs-class FoV)
    a(1).fov_half_angle_deg = acosd(1.0 - a(1).fov_sr / (2*pi));
    a(1).energy_band_keV    = [15.0, 250.0];
    a(1).A_eff_cm2          = 350.0;        % Meets PER-050 (>= 300 cm^2)
    a(1).mask_fwhm_arcmin   = 24.0;         % Mask element pitch / focal distance -> 24' FWHM
    a(1).loc_sys_arcmin     = 2.0;          % Thermo-elastic + mask alignment floor (PER-020 <= 3')
    a(1).adcs_know_arcsec   = 30.0;         % Dual star trackers (redundant after BurstCube lesson)
    a(1).clock_acc_us       = 1.0;          % GNSS-disciplined oscillator (<= 10 us PER-080)
    a(1).onboard_proc_s     = 5.0;          % Autonomous onboard trigger & deconvolution [s]
    a(1).slew_capable       = false;        % Dedicated prompt localizer (alerts external X-ray/opt)
    a(1).alert_link_mode    = 'VHF_or_Iridium';

    % Mission Life, Disposal, Cost & TRL
    a(1).design_life_yr     = 3.0;          % Goal MIS-010 (3 yr)
    a(1).controlled_deorbit = false;        % Demisable SmallSat (<80 kg); perigee lowering to <320 km ensures <5 yr even at Solar Min
    a(1).cost_MUSD_nom      = 16.5;         % Parametric NASA Pioneers / ESA S-class SmallSat analogy
    a(1).cost_MUSD_unc      = 5.0;          % +/- 30% Phase A uncertainty
    a(1).trl                = 7;            % Scaled coded-mask CZT/CdTe + SmallSat bus heritage

    %% ========================================================================
    % ARCH 2: AGILE CODED-MASK MONOLITH (Flagship Reference — SVOM / Swift)
    %% ========================================================================
    a(2).id                 = 2;
    a(2).code               = 'ARCH-2';
    a(2).name               = 'Agile Coded-Mask Monolith (SVOM/Swift Ref.)';
    a(2).short_name         = 'Coded-Mask Monolith';
    a(2).archetype          = 'SVOM / Swift Flagship';
    a(2).num_sats           = 1;
    a(2).num_planes         = 1;
    a(2).sats_per_plane     = 1;

    a(2).h_km               = 600.0;
    a(2).a_m                = (const.Re_km + a(2).h_km) * 1e3;
    a(2).e                  = 0.0005;
    a(2).inc_deg            = 29.0;
    a(2).raan_deg           = [45.0];
    a(2).omega_deg          = 0.0;
    a(2).nu_deg             = [0.0];

    a(2).mass_wet_kg        = 850.0;
    a(2).mass_payload_kg    = 190.0;        % ECLAIRs (89.6 kg) + MXT + VT follow-up suite
    a(2).mass_total_kg      = 850.0;
    a(2).power_payload_W    = 210.0;
    a(2).power_bus_avg_W    = 650.0;
    a(2).A_drag_m2          = 3.20;
    a(2).A_srp_m2           = 4.00;
    a(2).Cd                 = 2.2;
    a(2).Cr                 = 1.3;
    a(2).Isp_s              = 220.0;
    a(2).prop_type          = 'Monopropellant Hydrazine';

    a(2).loc_principle      = 'coded_mask';
    a(2).pointing_law       = 'anti_solar';
    a(2).fov_sr             = 2.0;
    a(2).fov_half_angle_deg = acosd(1.0 - a(2).fov_sr / (2*pi));
    a(2).energy_band_keV    = [4.0, 250.0];
    a(2).A_eff_cm2          = 600.0;        % Large CdTe/CZT detector array
    a(2).mask_fwhm_arcmin   = 18.0;         % Higher mask-to-detector standoff
    a(2).loc_sys_arcmin     = 1.5;
    a(2).adcs_know_arcsec   = 15.0;
    a(2).clock_acc_us       = 1.0;
    a(2).onboard_proc_s     = 5.0;
    a(2).slew_capable       = true;         % Meets ARC-010..040 (onboard narrow-field follow-up)
    a(2).alert_link_mode    = 'VHF_or_Iridium';

    a(2).design_life_yr     = 3.0;
    a(2).controlled_deorbit = true;         % Mandatory SPOUA controlled re-entry (m > 500 kg, LIF-030)
    a(2).cost_MUSD_nom      = 180.0;        % SVOM / Swift class programmatic benchmark
    a(2).cost_MUSD_unc      = 45.0;
    a(2).trl                = 9;            % Flight-proven (Swift 21 yr, SVOM operating)

    %% ========================================================================
    % ARCH 3: TIMING-TRIANGULATION CONSTELLATION (HERMES / CAMELOT Operational 9-Sat)
    %% ========================================================================
    % Note: 3D geometric screening confirmed that a 6-sat narrow-FoV pathfinder rarely achieves
    % >= 4 simultaneous co-viewing satellites (ARC-060). Therefore ARCH-3 models a realistic
    % 9-satellite, 3-plane Walker-Delta constellation (3 planes x 3 sats, 2*pi sr hemispherical
    % uncollimated detectors) capable of continuous 3D baseline triangulation (CAMELOT/HERMES-Full).
    a(3).id                 = 3;
    a(3).code               = 'ARCH-3';
    a(3).name               = 'Timing-Triangulation Constellation (9-Sat Walker)';
    a(3).short_name         = 'TDOA Constellation (9x)';
    a(3).archetype          = 'HERMES-Full / CAMELOT (3 planes x 3 sats)';
    a(3).num_sats           = 9;            % 9 spacecraft to satisfy ARC-060 (>= 4 co-viewing)
    a(3).num_planes         = 3;            % 3 distinct orbital planes (exceeds ARC-070 >= 2)
    a(3).sats_per_plane     = 3;

    a(3).h_km               = 535.0;
    a(3).a_m                = (const.Re_km + a(3).h_km) * 1e3;
    a(3).e                  = 0.0005;
    a(3).inc_deg            = 28.5;
    % Walker Delta 9/3/1: 3 planes spaced by 120 deg RAAN, 3 sats/plane spaced by 120 deg (40 deg inter-plane phasing)
    a(3).raan_deg           = [0, 0, 0, 120, 120, 120, 240, 240, 240];
    a(3).omega_deg          = 0.0;
    a(3).nu_deg             = [0, 120, 240, 40, 160, 280, 80, 200, 320];

    a(3).mass_wet_kg        = 24.0;         % 12U CubeSat / microsat per node
    a(3).mass_payload_kg    = 3.0;          % Wide-FoV CsI/GAGG + SDD/SiPM detector
    a(3).mass_total_kg      = 9 * 24.0;     % 216 kg total constellation wet mass
    a(3).power_payload_W    = 7.0;
    a(3).power_bus_avg_W    = 25.0;         % Per satellite
    a(3).A_drag_m2          = 0.18;
    a(3).A_srp_m2           = 0.22;
    a(3).Cd                 = 2.2;
    a(3).Cr                 = 1.25;
    a(3).Isp_s              = 80.0;         % Water resistojet / cold gas
    a(3).prop_type          = 'Water Resistojet / Cold Gas';

    a(3).loc_principle      = 'tdoa_triangulation';
    a(3).pointing_law       = 'zenith';     % Uncollimated scintillator sees full unocculted sky down to Earth limb (~112 deg)
    a(3).fov_sr             = 8.6;          % Full unocculted sky per node (~68% of 4*pi sr at 535 km)
    a(3).fov_half_angle_deg = 112.0;        % Limited by Earth limb occultation rather than collimator
    a(3).energy_band_keV    = [10.0, 2000.0];
    a(3).A_eff_cm2          = 120.0;        % Per satellite (CAMELOT-class 3U/6U scintillator area)
    a(3).clock_acc_us       = 0.5;          % GNSS-disciplined clock (<= 1.0 us ARC-050)
    a(3).cc_timing_ref_us   = 75.0;         % Cross-correlation timing jitter at SNR=10 (Fiore et al. 2020)
    a(3).loc_sys_arcmin     = 1.5;
    a(3).adcs_know_arcsec   = 300.0;
    a(3).onboard_proc_s     = 6.0;
    a(3).slew_capable       = false;
    a(3).alert_link_mode    = 'VHF_or_Iridium';

    a(3).design_life_yr     = 3.0;
    a(3).controlled_deorbit = false;
    a(3).cost_MUSD_nom      = 32.0;         % 9 nodes + deployment + constellation ops
    a(3).cost_MUSD_unc      = 10.0;
    a(3).trl                = 5;            % No published in-orbit GRB triangulation yet (Slide 20/24)

    %% ========================================================================
    % ARCH 4: SOFT X-RAY LOBSTER-EYE IMAGER (Einstein Probe WXT Class)
    %% ========================================================================
    a(4).id                 = 4;
    a(4).code               = 'ARCH-4';
    a(4).name               = 'Soft X-Ray Lobster-Eye Imager (EP-WXT Ref.)';
    a(4).short_name         = 'Lobster-Eye (Soft-X)';
    a(4).archetype          = 'Einstein Probe (WXT)';
    a(4).num_sats           = 1;
    a(4).num_planes         = 1;
    a(4).sats_per_plane     = 1;

    a(4).h_km               = 550.0;
    a(4).a_m                = (const.Re_km + a(4).h_km) * 1e3;
    a(4).e                  = 0.0005;
    a(4).inc_deg            = 29.0;
    a(4).raan_deg           = [45.0];
    a(4).omega_deg          = 0.0;
    a(4).nu_deg             = [0.0];

    a(4).mass_wet_kg        = 450.0;
    a(4).mass_payload_kg    = 140.0;        % MPO optics modules + CMOS focal plane + thermal control
    a(4).mass_total_kg      = 450.0;
    a(4).power_payload_W    = 180.0;
    a(4).power_bus_avg_W    = 420.0;
    a(4).A_drag_m2          = 2.00;
    a(4).A_srp_m2           = 2.50;
    a(4).Cd                 = 2.2;
    a(4).Cr                 = 1.25;
    a(4).Isp_s              = 210.0;
    a(4).prop_type          = 'Monopropellant Hydrazine';

    a(4).loc_principle      = 'lobster_eye';
    a(4).pointing_law       = 'anti_solar';
    a(4).fov_sr             = 1.1;          % 3600 deg^2 (Einstein Probe WXT — note: < 1.4 sr PER-060!)
    a(4).fov_half_angle_deg = acosd(1.0 - a(4).fov_sr / (2*pi));
    a(4).energy_band_keV    = [0.5, 4.0];   % Soft X-rays ONLY (misses hard/short prompt GRBs!)
    a(4).A_eff_cm2          = 3.0;          % Focusing optics area (high S/B due to focusing)
    a(4).psf_fwhm_arcmin    = 5.0;          % MPO cruciform core FWHM
    a(4).loc_sys_arcmin     = 1.0;
    a(4).adcs_know_arcsec   = 20.0;
    a(4).clock_acc_us       = 10.0;
    a(4).onboard_proc_s     = 6.0;
    a(4).slew_capable       = true;
    a(4).alert_link_mode    = 'VHF_or_Iridium';

    a(4).design_life_yr     = 3.0;
    a(4).controlled_deorbit = false;        % Perigee lowering to <280 km (or SPOUA if non-demisable)
    a(4).cost_MUSD_nom      = 75.0;
    a(4).cost_MUSD_unc      = 20.0;
    a(4).trl                = 8;            % Einstein Probe operating since Jan 2024

    %% ========================================================================
    % ARCH 5: ALL-SKY COUNT-RATE RATIO MONITOR (Fermi GBM / GECAM Class)
    %% ========================================================================
    a(5).id                 = 5;
    a(5).code               = 'ARCH-5';
    a(5).name               = 'All-Sky Count-Rate Monitor (GECAM/GBM Ref.)';
    a(5).short_name         = 'Count-Rate Dome (GECAM)';
    a(5).archetype          = 'GECAM (Twin 180 deg Nodes)';
    a(5).num_sats           = 2;
    a(5).num_planes         = 1;
    a(5).sats_per_plane     = 2;

    a(5).h_km               = 550.0;
    a(5).a_m                = (const.Re_km + a(5).h_km) * 1e3;
    a(5).e                  = 0.0005;
    a(5).inc_deg            = 29.0;
    a(5).raan_deg           = [45.0, 45.0];
    a(5).omega_deg          = 0.0;
    a(5).nu_deg             = [0.0, 180.0]; % Opposite-phase cancels Earth occultation

    a(5).mass_wet_kg        = 150.0;
    a(5).mass_payload_kg    = 45.0;         % 25 GRD + 8 CPD scintillator dome
    a(5).mass_total_kg      = 300.0;
    a(5).power_payload_W    = 60.0;
    a(5).power_bus_avg_W    = 140.0;
    a(5).A_drag_m2          = 0.95;
    a(5).A_srp_m2           = 1.15;
    a(5).Cd                 = 2.2;
    a(5).Cr                 = 1.25;
    a(5).Isp_s              = 70.0;
    a(5).prop_type          = 'Cold Gas / Micro-Resistojet';

    a(5).loc_principle      = 'count_rate_ratio';
    a(5).pointing_law       = 'zenith';
    a(5).fov_sr             = 8.6;          % Full unocculted sky per node (twin opposite-phase = 4*pi sr all-sky)
    a(5).fov_half_angle_deg = 112.0;
    a(5).energy_band_keV    = [8.0, 2000.0];
    a(5).A_eff_cm2          = 380.0;        % Effective on-axis crystal area
    a(5).loc_sys_core_deg   = 3.71;         % Connaughton et al. (2015) ApJS 216, 32 [CORE]
    a(5).loc_sys_tail_deg   = 14.3;         % Non-Gaussian tail (10% weight)
    a(5).adcs_know_arcsec   = 120.0;
    a(5).clock_acc_us       = 2.0;
    a(5).onboard_proc_s     = 4.0;
    a(5).slew_capable       = false;
    a(5).alert_link_mode    = 'VHF_or_Iridium';

    a(5).design_life_yr     = 3.0;
    a(5).controlled_deorbit = false;
    a(5).cost_MUSD_nom      = 28.0;
    a(5).cost_MUSD_unc      = 8.0;
    a(5).trl                = 9;

    %% ========================================================================
    % ARCH 6: POLAR SSO SMALLSAT REFERENCE (Controlled Orbit Trade Comparison)
    %% ========================================================================
    % Identical SmallSat spacecraft & coded-mask payload to ARCH-1, placed in
    % 500 km, 97.4 deg Sun-Synchronous Orbit to isolate pure orbital penalties!
    a(6)                    = a(1);
    a(6).id                 = 6;
    a(6).code               = 'ARCH-6';
    a(6).name               = 'Polar SSO Coded-Mask SmallSat (Orbit Trade Ref.)';
    a(6).short_name         = 'SSO SmallSat (97.5 deg)';
    a(6).archetype          = 'Arch-1 Payload in 10:30 LTAN SSO';
    a(6).h_km               = 535.0;
    a(6).a_m                = (const.Re_km + a(6).h_km) * 1e3;
    a(6).inc_deg            = 97.54;        % Exact 535 km SSO inclination (FAILS ENV-050 <= 30 deg)
    a(6).raan_deg           = [255.0];      % 10:30 LTAN at June solstice epoch
    a(6).cost_MUSD_nom      = 15.0;         % Slightly cheaper rideshare launch to SSO
    a(6).cost_MUSD_unc      = 4.5;

    archs = a;
end
