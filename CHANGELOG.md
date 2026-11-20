# Changelog

All notable changes to the **TUM Space Mission Design — GRB Alert Mission Analysis Suite (MATLAB)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] — 2026-11-20

Complete from-scratch architectural rebuild to aerospace-grade physical fidelity, automated verification, and full compliance with the TUM Space Mission Design Report Guide (WS 2026/27), ECSS-E-ST-10C/10-04C/10-06C/32-10C, ESA ESSB-ST-U-007, and NASA/SP-2016-6105 Rev2.

### Added
- **Live Aerospace Toolbox Space Environment Models**:
  - `config/build_atmosphere_model.m`: Live orbit-averaged **NRLMSISE-00** atmospheric density profiles across three ECSS-E-ST-10-04C solar bounding regimes (`solar_min` $F_{10.7}=70$, `solar_nom` $F_{10.7}=140$, `solar_max` $F_{10.7}=220$) with exponential fallback.
  - `analysis/build_geomagnetic_model.m` & `analysis/analyze_radiation_saa.m`: Live **IGRF-14** (epoch 2028.42) 3D gridded interpolants resolving both the altitude-dependent South Atlantic Anomaly inner proton belt ($|B| < 22.2\,\mu\text{T}$) and outer Van Allen polar/auroral electron horns ($L > 3.2$).
- **Single Source of Truth Requirements Module**:
  - `config/mission_requirements.m`: Centralized quantitative thresholds and goals transcribed from `GRB_mission_analysis.xlsx` and `SRR.tex` (`MIS`, `PER`, `IF`, `OPS`, `ENV`, `PHY`, `LIF`, `ARC`).
- **Parametric 2D Orbit Selection Trade Study**:
  - `analysis/analyze_orbit_trade_space.m` & `plots/plot_orbit_trade_maps.m`: 99-orbit parametric sweep ($400\text{–}650\text{ km} \times 0^\circ\text{–}97.4^\circ$) mapping radiation duty cycle, VHF coverage, Solar-Min 5-year passive lifetime, Solar-Max 3-year drag $\Delta v$, and the feasible SmallSat LEO corridor.
- **Full-Year Solar Beta & Conical Shadow Envelope**:
  - `analysis/analyze_eclipse_annual.m` & `plots/plot_eclipse_beta_annual.m`: Conical umbra/penumbra shadow model plus 365-day $J_2$-precessed $\beta(t)$ history delivering exact Worst Cold Case and Worst Hot Case boundary conditions for Power and Simscape Thermal.
- **First-Principles 3D Celestial Coverage & Monte Carlo Localization Error Budget**:
  - `analysis/analyze_sky_coverage_3d.m`: 1,000-pixel Fibonacci celestial sphere simulator with $+80\text{ km}$ atmospheric gamma-ray limb, Sun/Moon exclusion (`OPS-060`), boresight pointing laws, and multi-satellite $k$-fold simultaneous co-viewing (`ARC-060`).
  - `analysis/analyze_localization_yield.m`: 3,000-burst Monte Carlo GRB population (broken power-law $\log N\text{–}\log P$, Band spectra) with Skinner coded-mask SNR/centroiding, Einstein Probe WXT soft X-ray focusing, Connaughton et al. (2015) count-rate ratios, and exact **3D Fisher Information Matrix Cramér-Rao Lower Bounds (CRLB)** for TDOA constellations.
- **Multi-Path Communications & RF Link Budget**:
  - `analysis/analyze_comms_latency.m` & `plots/plot_alert_latency_cdf.m`: 47-station equatorial VHF network (137.5 MHz, 600 bps, worst-case $5^\circ$ link margin verification), commercial **Iridium NEXT SBD/Certus** LEO relay, and primary S/X-band TT&C store-and-forward, including 4th-order-statistic correlation delay for TDOA constellations.
- **Objective Multi-Criteria Decision Analysis (MCDA) & Sensitivity Engine**:
  - `analysis/evaluate_tradeoff_study.m` & `plots/plot_tradeoff_dashboard.m`: 7-gate mandatory requirements screening, physical KPI matrix with units, **TOPSIS** across 4 objective weighting schemes (Equal, Shannon Information Entropy, Science Priority, SmallSat Cost/SWaP), and 10,000-trial Dirichlet Monte Carlo weight-space sensitivity analysis.
- **Automated Verification & Literature Plausibility Suite**:
  - `verification/verify_mission_analysis.m`: 6 quantitative verification tests (two-body conservation, $J_2$ SSO precession, conical eclipse hand-calc, Gauss drag decay, Swift LEO benchmark, and SVOM VHF benchmark — 6/6 passing).
- **Automated Subsystem & Report Exporters**:
  - `export/export_deliverables.m`: Generates `results/Subsystem_Inputs.json`, `results/Mission_Analysis_Summary.csv`, `results/Mission_Analysis_Report.md`, and LaTeX booktabs tables (`results/tables/mission_analysis_table.tex`, `results/tables/verification_table.tex`).

### Changed
- Upgraded numerical propagator (`core/orbit_propagator.m`) from `ode45` ($J_2, J_3$, static exponential drag) to **`ode113`** (`RelTol=1e-9, AbsTol=1e-10`) with $J_2 + J_3 + J_4$, live NRLMSISE-00 co-rotating drag, smooth $C^1$ cubic Hermite conical penumbra SRP, and Gauss-variational drag work integration over 5 days at 10 s cadence.
- Upgraded frame transformations (`core/eci2ecef_iau.m`, `core/ecef2lla_wgs84.m`) to fully vectorized IAU-2000/2006 epoch DCM and vectorized Bowring WGS-84 geodetic LLA.
- Expanded architecture trade space (`config/get_architecture_configs.m`) to 6 traceable candidates including the SRR target **Compact Coded-Mask SmallSat (`ARCH-1`, 75 kg, 535 km, 28.5°)**, 9-satellite 3-plane Walker TDOA constellation (`ARCH-3`), and controlled SSO orbit trade (`ARCH-6`).
- Rebuilt all figures with consistent 250-DPI light-theme TUM academic styling (`plots/style_figure.m`) and base-MATLAB `topo.mat` world coastlines.

### Fixed
- Eliminated subjective 1–5 AHP scales and arbitrary team weights (non-compliant with TUM Report Guide p. 4).
- Fixed double-counted coded-mask open fraction on `A_eff` in SNR calculations.
- Fixed MATLAB R2026a dark-mode figure export artifacts and TeX interpreter warnings (`\leq`, `\geq`, `^{\circ}`).
- Fixed ESA 5-year debris compliance sign error by evaluating passive lifetime under **Solar Minimum** (slowest decay) and drag makeup $\Delta v$ under **Solar Maximum** (highest drag).

---

## [1.1.0] — 2026-11-16

### Added
- Expanded trade-off suite from 3 to 5 candidate architectures aligned with Slide 20 (`GRB Alert Mission Design.pptx`).
- Added 41-station equatorial VHF alert network, alert latency CDF analysis (`analyze_alert_latency.m`), burst yield sizing (`analyze_burst_yield.m`), ESA 5-year lifetime module (`analyze_orbit_lifetime.m`), and AHP trade-off scoring (`evaluate_tradeoff_matrix.m`).

### Fixed
- Fixed critical osculating-radius secular drag decay bug (which produced erroneous negative $\Delta v$ and negative propellant mass) by introducing Gauss-variational drag work integration inside `orbit_propagator.m`.

---

## [1.0.0] — 2026-11-13

### Added
- Initial MATLAB mission analysis prototype comparing 3 architectures (Low-Inc Monolith, Twin-Node Constellation, SSO SmallSat) with 3-day `ode45` propagation ($J_2, J_3$, US Standard 1976 exponential drag), cylindrical eclipse analysis, polygon SAA blanking, ground contacts, and $\Delta v$ budget.
