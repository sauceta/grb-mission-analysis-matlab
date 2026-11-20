function comms = ground_stations_config()
% GROUND_STATIONS_CONFIG Defines TT&C stations, SVOM-heritage equatorial VHF alert
% network (45 nodes), and commercial/institutional space relay benchmarks (Iridium NEXT, TDRSS).
%
% References:
%   - SVOM VHF Alert Network (~45 equatorial stations, 137 MHz, 600 bps, ~93% coverage):
%     Atteia et al. (2024), Bernardini et al. (2026) [arXiv:2604.24263]
%   - Mission requirements: IF-020 (<=128 B), IF-030 (>=600 bps), IF-040 (EIRP 0 dBW), OPS-020 (>=90%)
%   - Iridium NEXT SBD/Certus LEO relay flight heritage (SpIRIT, BurstCube studies)
%
% TUM Space Mission Design (WS 2026/27) — GRB Alert Mission

    %% 1. Primary TT&C & Bulk Science Downlink Stations (S-band / X-band)
    ttc_data = {
        % Name,                 Lat [deg], Lon [deg], Alt [m], Mask [deg], G/T [dB/K], Rate [Mbps]
        'Kourou (ESA)',           5.2514,  -52.8047,    10.0,   5.0,        26.5,      10.0;
        'Malindi (ASI/ESA)',     -2.9956,   40.1945,    10.0,   5.0,        24.0,      10.0;
        'Weilheim (DLR/GSOC)',   47.8789,   11.0828,   560.0,   5.0,        28.0,      15.0;
        'Svalbard (KSAT Polar)', 78.2297,   15.4078,   400.0,   5.0,        27.0,      15.0;
        'Hartebeesthoek (SANSA)',-25.8872,  27.7072,  1550.0,   5.0,        25.0,      10.0
    };

    for i = 1:size(ttc_data, 1)
        gs_ttc(i).name      = ttc_data{i, 1};
        gs_ttc(i).lat       = ttc_data{i, 2};
        gs_ttc(i).lon       = ttc_data{i, 3};
        gs_ttc(i).alt       = ttc_data{i, 4};
        gs_ttc(i).mask      = ttc_data{i, 5};
        gs_ttc(i).G_over_T  = ttc_data{i, 6}; % [dB/K]
        gs_ttc(i).rate_Mbps = ttc_data{i, 7};
        gs_ttc(i).type      = 'TTC';
    end

    %% 2. Global Equatorial & Intertropical VHF Alert Network (45 SVOM-Heritage Sites)
    % Distributed along +/- 30 deg latitude including oceanic island relays to close
    % Pacific, Atlantic, and Indian Ocean gaps (>= 90% orbital coverage per OPS-020).
    vhf_data = {
        'VHF-Hawaii',             19.82, -155.46,  100;
        'VHF-Tahiti',            -17.65, -149.43,   15;
        'VHF-Marquesas',          -8.91, -140.10,   30;
        'VHF-Clipperton/Revill',  18.78, -110.95,   20;
        'VHF-Easter Island',     -27.11, -109.36,   50;
        'VHF-Baja California',    24.14, -110.31,   30;
        'VHF-Galapagos',          -0.74,  -90.31,   20;
        'VHF-Oaxaca (Mexico)',    17.07,  -96.72, 1550;
        'VHF-Lima (Peru)',       -12.04,  -77.04,  150;
        'VHF-Bogota (Colombia)',   4.71,  -74.07, 2600;
        'VHF-Cordoba (Arg.)',    -31.42,  -64.18,  400;
        'VHF-Martinique',         14.64,  -61.02,   20;
        'VHF-Bermuda',            32.30,  -64.75,   20;
        'VHF-Kourou',              5.25,  -52.80,   10;
        'VHF-Manaus (Brazil)',    -3.12,  -60.02,   90;
        'VHF-Natal (Brazil)',     -5.79,  -35.21,   30;
        'VHF-Rio (Brazil)',      -22.91,  -43.17,   20;
        'VHF-Cape Verde',         14.93,  -23.51,   15;
        'VHF-Canary Islands',     28.29,  -16.63,  200;
        'VHF-Dakar (Senegal)',    14.71,  -17.46,   25;
        'VHF-Ascension Island',   -7.94,  -14.36,   80;
        'VHF-Saint Helena',      -15.96,   -5.71,  150;
        'VHF-Libreville',          0.39,    9.45,   30;
        'VHF-Windhoek',          -22.56,   17.08, 1700;
        'VHF-Nairobi/Malindi',    -2.99,   40.19,   10;
        'VHF-Djibouti',           11.58,   43.14,   15;
        'VHF-Antananarivo',      -18.87,   47.50, 1280;
        'VHF-Reunion Island',    -20.88,   55.45,   50;
        'VHF-Seychelles',         -4.67,   55.49,   20;
        'VHF-Diego Garcia',       -7.32,   72.42,    5;
        'VHF-Maldives',            4.17,   73.50,    2;
        'VHF-Bangalore',          12.97,   77.59,  920;
        'VHF-Sri Lanka',           6.92,   79.86,   10;
        'VHF-Cocos Islands',     -12.19,   96.83,    5;
        'VHF-Phuket',              7.88,   98.39,   20;
        'VHF-Singapore',           1.35,  103.82,   15;
        'VHF-Hainan',             19.20,  109.70,   50;
        'VHF-Manila',             14.59,  120.98,   15;
        'VHF-Okinawa',            26.21,  127.68,   40;
        'VHF-Darwin',            -12.46,  130.84,   30;
        'VHF-Guam',               13.44,  144.79,   60;
        'VHF-Port Moresby',       -9.44,  147.18,   40;
        'VHF-Noumea',            -22.27,  166.45,   30;
        'VHF-Kwajalein',           8.71,  167.73,    5;
        'VHF-Tarawa (Kiribati)',   1.32,  172.97,    3;
        'VHF-Fiji',              -18.14,  178.44,   20;
        'VHF-Samoa',             -13.83, -171.76,   20
    };

    for k = 1:size(vhf_data, 1)
        gs_vhf(k).name      = vhf_data{k, 1};
        gs_vhf(k).lat       = vhf_data{k, 2};
        gs_vhf(k).lon       = vhf_data{k, 3};
        gs_vhf(k).alt       = vhf_data{k, 4};
        gs_vhf(k).mask      = 5.0;
        gs_vhf(k).G_over_T  = -17.0; % Typical 137 MHz crossed-Yagi + LNA (G=9 dBi, Tsys=400 K -> -17 dB/K)
        gs_vhf(k).rate_bps  = 600.0; % IF-030 (SVOM VHF standard)
        gs_vhf(k).type      = 'VHF_Alert';
    end

    %% 3. RF Link Parameters (VHF Alert Link & S/X-band Science Downlink)
    comms.vhf_rf.freq_Hz          = 137.5e6;   % VHF space-to-Earth meteorology/science band [Hz]
    comms.vhf_rf.eirp_dBW         = 0.0;       % Spacecraft radiated EIRP [dBW] (IF-040)
    comms.vhf_rf.bitrate_bps      = 600.0;     % Alert link data rate [bit/s] (IF-030)
    comms.vhf_rf.packet_bytes     = 128;       % Alert packet size [bytes] (IF-020)
    comms.vhf_rf.repeats          = 2;         % Transmit + 1 repeat (FUN-110)
    comms.vhf_rf.atm_pol_loss_dB  = 2.5;       % Ionospheric scintillation + polarization + impl. loss [dB]
    comms.vhf_rf.req_ebn0_dB      = 9.6;       % BPSK/QPSK + FEC for BER < 1e-5 [dB]

    %% 4. Space Relay Benchmarks (Iridium NEXT SBD/Certus & GEO TDRSS)
    % Iridium NEXT: 66 cross-linked LEO satellites at 780 km -> ~99.2% global availability
    comms.iridium.name             = 'Iridium NEXT SBD/Certus Relay';
    comms.iridium.availability     = 0.992;    % Link availability fraction
    comms.iridium.acq_median_s     = 12.0;     % Modem registration + SBD gateway transit [s]
    comms.iridium.acq_sigma_logn   = 0.45;     % Log-normal spread (tail up to ~40-60 s during handover)
    comms.iridium.gcn_broker_s     = 2.0;      % GCN Kafka ingestion [s]
    comms.iridium.power_W          = 4.5;      % Average standby/burst transceiver power [W]
    comms.iridium.mass_kg          = 0.45;     % Space-qualified Iridium modem + patch antenna [kg]

    comms.ttc_stations = gs_ttc;
    comms.vhf_stations = gs_vhf;
    comms.all_stations = [rmfield(gs_ttc, 'rate_Mbps'), rmfield(gs_vhf, 'rate_bps')];
end
