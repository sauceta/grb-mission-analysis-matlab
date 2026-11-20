function req = mission_requirements()
% MISSION_REQUIREMENTS Single Source of Truth for quantitative GRB mission requirements.
% Transcribed directly from GRB_mission_analysis.xlsx (sheet 'Requirements'),
% GRB Alert Mission Design.pptx (Slides 14-15), and SRR.tex (Sections 1.4 & 2.4).
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    % --- Mission Requirements (MIS) ---
    req.MIS_010_science_life_yr      = 2.0;     % Threshold nominal science ops [years] (Goal: 3.0 yr)
    req.MIS_010_goal_yr              = 3.0;
    req.MIS_020_min_bursts_per_yr    = 40.0;    % Threshold detected & localized GRBs/yr (Goal: 150/yr)
    req.MIS_020_goal_bursts_per_yr   = 150.0;
    req.MIS_030_loc_r90_arcmin       = 10.0;    % 90% confidence radius [arcmin] (Goal: 3.0 arcmin)
    req.MIS_030_goal_arcmin          = 3.0;
    req.MIS_040_alert_fast_s         = 30.0;    % Fast alert latency threshold [s]
    req.MIS_040_alert_fast_pct       = 66.0;    % Minimum fraction <= 30 s [%] (Goal: 90%)
    req.MIS_040_alert_fast_goal_pct  = 90.0;
    req.MIS_050_alert_slow_min       = 20.0;    % Extended alert latency threshold [min]
    req.MIS_050_alert_slow_pct       = 95.0;    % Minimum fraction <= 20 min [%]

    % --- Performance Requirements (PER) ---
    req.PER_010_loc_r90_at_snr8_arcmin = 10.0;  % <= 10 arcmin at SNR >= 8
    req.PER_010_min_snr                = 8.0;
    req.PER_020_loc_sys_arcmin         = 3.0;   % Systematic localization error <= 3 arcmin
    req.PER_040_peak_flux_cgs          = 2.5e-8;% 1-s peak flux sensitivity (5-50 keV) [erg/cm^2/s]
    req.PER_040_peak_flux_ph           = 0.5;   % Equivalent ~0.5 ph/cm^2/s (50-300 keV, SRR.tex)
    req.PER_050_min_aeff_cm2           = 300.0; % Effective area (15-150 keV) [cm^2]
    req.PER_060_min_fov_sr             = 1.4;   % Instantaneous Field of View [sr] (SRR target: 2.0 sr)
    req.PER_070_min_duty_cycle_pct     = 60.0;  % Observing duty cycle averaged over 30 days [%]
    req.PER_080_time_acc_us            = 10.0;  % Absolute UTC time accuracy (1-sigma) [us]
    req.PER_100_trigger_snr            = 6.5;   % Alert trigger significance [sigma]
    req.PER_110_low_energy_eol_keV     = 30.0;  % EOL low-energy threshold [keV]

    % --- Interface & Communications Requirements (IF & OPS) ---
    req.IF_020_alert_packet_bytes      = 128;   % Maximum alert message size [bytes]
    req.IF_030_alert_min_bitrate_bps   = 600.0; % Alert link minimum data rate [bit/s]
    req.IF_040_alert_min_eirp_dBW      = 0.0;   % Radiated spacecraft EIRP reference [dBW]
    req.OPS_020_alert_orbit_cov_pct    = 90.0;  % Alert reception orbit coverage [%]
    req.OPS_060_sun_excl_deg           = 35.0;  % Sun avoidance half-angle [deg] (Swift/SVOM heritage)
    req.OPS_060_moon_excl_deg          = 10.0;  % Moon avoidance half-angle [deg]

    % --- Environment, Physical & Lifetime / Disposal Requirements (ENV, PHY, LIF) ---
    req.ENV_010_max_bg_rate_cts_cm2_s  = 1.5;   % Max in-orbit background count rate [cts/cm^2/s]
    req.ENV_050_max_inclination_deg    = 30.0;  % Circular LEO inclination <= 30 deg [deg]
    req.PHY_010_payload_mass_tbc_kg    = 25.0;  % SmallSat payload mass envelope (SRR: <=25 kg; workbook TBC 10 kg)
    req.PHY_030_max_science_data_Gb_day = 1.0;  % Max daily science data volume [Gbit/day]
    req.LIF_010_max_post_mission_yr    = 5.0;   % ESA ESSB-ST-U-007 5-year disposal rule [years]
    req.LIF_020_min_disposal_prob      = 0.90;  % Disposal success probability [-]
    req.LIF_030_max_casualty_risk      = 1e-4;  % Expected re-entry casualties [-]
    req.LIF_030_controlled_mass_kg     = 500.0; % Heuristic threshold requiring controlled SPOUA re-entry [kg]

    % --- Architecture-Forked Requirements (ARC) ---
    req.ARC_010_slew_time_s            = 200.0; % Follow-up telescope architecture slew time [s]
    req.ARC_050_const_time_acc_us      = 1.0;   % Constellation UTC timing accuracy [us]
    req.ARC_060_const_min_coview_sats  = 4;     % Constellation minimum simultaneous viewers [-]
    req.ARC_070_const_min_planes       = 2;     % Constellation minimum distinct orbital planes [-]

    % --- SmallSat Programmatic Target Envelope (SRR.tex Section 1.4 & Slide 22) ---
    req.PROG_smallsat_mass_cap_kg      = 80.0;  % Target SmallSat wet mass envelope [kg]
    req.PROG_smallsat_cost_cap_MUSD    = 20.0;  % NASA Pioneers / SmallSat cost cap [M USD]
end
