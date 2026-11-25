%% CHECK_DETECTION_RATE  Verify the SRR flow-down "PER-040 + PER-065 -> 40 GRB/yr" (MIS-020)
% Runs the burst population of the team's mission-analysis suite
% (MATLAB_Mission_Analysis/analysis/analyze_localization_yield.m, v2.0) through the
% first-principles coded-mask cameras A1, A2 and A0 of tradeoff_model.py.
%
% Population (copied unchanged from analyze_localization_yield.m):
%   900 GRB/yr all-sky above P = 0.25 ph/cm2/s (1-s peak, 15-150 keV);
%   broken power law N(>P): slope 0.85 below 2 ph/cm2/s, 1.55 above; P_max = 100;
%   Band spectrum alpha = -1, beta = -2.3; Epeak lognormal, 85% long (144 keV), 15% short (413 keV);
%   integration 1.5 s (long) / 0.25 s (short).
% Camera (tradeoff_model.py): Eq. (2) SNR, 5-50 keV band, rho = 0.5, eps = 0.8,
%   b = 3.0 cts/cm2/s (ENV-010), square half-coded FoV, Omega*eta_eff = 0.75 sr.
% Only stated simplification: partial coding inside the FoV is ignored (optimistic).
%
% Run from this folder:  matlab -batch "check_detection_rate"

clear; clc;
rng(2026);

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end

%% Camera parameters from generated/results.csv
cams = read_cameras(fullfile(here, '..', 'generated', 'results.csv'), {'A1', 'A2', 'A0'});
rho = 0.5; eps_d = 0.8; b_bkg = 3.0; eta_eff = 0.74; Omega = 0.75 / eta_eff;
alpha_fov = asin(sqrt(sin(Omega / 4)));          % square FoV half-angle per axis [rad]
E_lo = 5; E_hi = 50;                             % PER-040 band [keV]
snr_trig = 6.5; snr_loc = 8.0;                   % PER-100, PER-010

%% Burst population (identical to the mission-analysis suite)
N_MC = 400000; R_allsky = 900;
P15  = sample_grb_flux(rand(1, N_MC));
is_short = rand(1, N_MC) < 0.15;
E_peak = zeros(1, N_MC);
E_peak(~is_short) = exp(log(144.0) + 0.65 * randn(1, sum(~is_short)));
E_peak(is_short)  = exp(log(413.0) + 0.55 * randn(1, sum(is_short)));
E_peak = max(15.0, min(3000.0, E_peak));
t_int = 1.5 * ones(1, N_MC); t_int(is_short) = 0.25;
f_band = band_conversion(E_peak, E_lo, E_hi);   % photon flux 5-50 keV / 15-150 keV
P = P15 .* f_band;                               % ph/cm2/s in the camera band

% Directions uniform inside the square FoV; on-axis cosine applied to the signal
n_draw = ceil(1.3 * N_MC * 4 * pi / Omega);      % FoV covers Omega/4pi of the sky
u = randn(3, n_draw); u = u ./ vecnorm(u);
inside = u(3, :) > 0 & abs(atan2(u(1, :), u(3, :))) < alpha_fov & abs(atan2(u(2, :), u(3, :))) < alpha_fov;
cosv = u(3, inside); cosv = cosv(1:N_MC);

rate_in_fov = R_allsky * Omega * eta_eff / (4 * pi);   % bursts/yr above P_min in view

fprintf('Population: %d GRB/yr all-sky above 0.25 ph/cm2/s; %.1f/yr fall in Omega*eta = %.2f sr\n', ...
    R_allsky, rate_in_fov, Omega * eta_eff);
fprintf('Median 5-50 / 15-150 keV photon-flux ratio of the population: %.2f\n\n', median(f_band));
fprintf('%-4s %8s %10s %10s %9s %9s %9s %10s\n', 'Cam', 'A [cm2]', 'Ndet [/yr]', 'Nu [/yr]', 'f_loc', 'beta_eff', 'MIS-020', 'flow-down');
out = struct();
for k = 1:numel(cams)
    A = cams(k).area;
    S = P .* cosv;
    snr = sqrt(rho * (1 - rho)) * eps_d .* S .* sqrt(A .* t_int) ./ sqrt(b_bkg + (1 - rho) * eps_d .* S);
    n_det = rate_in_fov * mean(snr >= snr_trig);
    n_u   = rate_in_fov * mean(snr >= snr_loc);
    % Local slope of the integral distribution around the trigger threshold
    n_lo = mean(snr >= snr_trig / 1.2); n_hi = mean(snr >= snr_trig * 1.2);
    beta_eff = log(n_lo / n_hi) / log(1.44);
    out(k).name = cams(k).name; out(k).area = A; out(k).n_det = n_det; out(k).n_u = n_u;
    out(k).beta_eff = beta_eff; out(k).flowdown = cams(k).n_det;
    fprintf('%-4s %8.0f %10.1f %10.1f %9.2f %9.2f %9s %10.1f\n', cams(k).name, A, n_det, n_u, ...
        n_u / n_det, beta_eff, ternary(n_det >= 40, 'met', 'NOT met'), cams(k).n_det);
end

% Fraction of A2 triggers that sit at the population floor (truncation check)
A = cams(2).area;
snr_floor = sqrt(rho*(1-rho))*eps_d*(0.25*median(f_band))*sqrt(A*1.5)/sqrt(b_bkg);
fprintf('\nSNR of a floor burst (0.25 ph/cm2/s, on axis) on A2: %.1f (>= 6.5 means the population floor truncates A2)\n', snr_floor);

writetable(struct2table(out), fullfile(here, 'check_detection_rate_results.csv'));
fprintf('Saved check_detection_rate_results.csv\n');

%% ------------------------------------------------------------------------
function cams = read_cameras(fname, names)
    fid = fopen(fname, 'r'); hdr = strsplit(fgetl(fid), ',');
    ia = find(strcmp(hdr, 'area')); in = find(strcmp(hdr, 'n_det'));
    cams = struct('name', {}, 'area', {}, 'n_det', {});
    while true
        ln = fgetl(fid);
        if ~ischar(ln) || isempty(strtrim(ln)), break; end
        c = regexp(ln, ',(?=(?:[^"]*"[^"]*")*[^"]*$)', 'split');   % ignore commas inside quotes
        if any(strcmp(c{1}, names))
            cams(end+1) = struct('name', c{1}, 'area', str2double(c{ia}), 'n_det', str2double(c{in})); %#ok<AGROW>
        end
    end
    fclose(fid);
    [~, order] = ismember(names, {cams.name}); cams = cams(order);
end

function P = sample_grb_flux(u)
    % Copied from analyze_localization_yield.m (v2.0)
    P_min = 0.25; P_brk = 2.0; P_max = 100.0; a1 = 0.85; a2 = 1.55;
    w1 = (P_min^(-a1) - P_brk^(-a1)) / a1;
    c_match = P_brk^(a2 - a1);
    w2 = c_match * (P_brk^(-a2) - P_max^(-a2)) / a2;
    p1 = w1 / (w1 + w2);
    P = zeros(size(u)); m1 = u <= p1;
    u1 = u(m1) / p1;
    P(m1) = (P_min^(-a1) - u1 * (P_min^(-a1) - P_brk^(-a1))).^(-1.0 / a1);
    u2 = (u(~m1) - p1) / (1.0 - p1);
    P(~m1) = (P_brk^(-a2) - u2 * (P_brk^(-a2) - P_max^(-a2))).^(-1.0 / a2);
end

function f = band_conversion(E_peak, E_lo, E_hi)
    % Band (alpha = -1, beta = -2.3) photon flux in [E_lo, E_hi] relative to 15-150 keV,
    % same spectrum as analyze_localization_yield.m, evaluated on a finer grid.
    alpha = -1.0; beta = -2.3;
    Er = logspace(log10(15), log10(150), 200);
    Ei = logspace(log10(E_lo), log10(E_hi), 200);
    E0 = E_peak(:) / (2 + alpha); Eb = (alpha - beta) * E0;
    f = trapz(Ei, band(Ei, E0, Eb, alpha, beta), 2) ./ trapz(Er, band(Er, E0, Eb, alpha, beta), 2);
    f = f.';
end

function phi = band(E, E0, Eb, alpha, beta)
    E = repmat(E, numel(E0), 1); E0 = repmat(E0, 1, size(E, 2)); Eb = repmat(Eb, 1, size(E, 2));
    lo = E <= Eb;
    phi = zeros(size(E));
    phi(lo) = (E(lo) / 100).^alpha .* exp(-E(lo) ./ E0(lo));
    phi(~lo) = (Eb(~lo) / 100).^(alpha - beta) .* exp(beta - alpha) .* (E(~lo) / 100).^beta;
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
