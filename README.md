# GRB Alert Mission — MATLAB Mission Analysis Suite (v2.0)

**Course:** Space Mission Design (WS 2026/27) — Project 2: *Space System for Gamma-Ray Burst Alert*  
**Institution:** Chair of Spacecraft Systems, Technical University of Munich (TUM)  
**Standards:** ECSS-E-ST-10C Rev.1 · ECSS-E-ST-10-04C · ECSS-E-ST-10-06C · ECSS-E-ST-32-10C · ESA ESSB-ST-U-007 · NASA/SP-2016-6105 Rev2

An end-to-end, aerospace-grade **MATLAB Mission Analysis, Orbit Trade-Off, Monte Carlo GRB Localization, Alert Latency, and Multi-Criteria Decision Analysis (MCDA)** pipeline built to evaluate post-*Swift* spaceborne Gamma-Ray Burst (GRB) alert architectures.

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

---

## Key Capabilities

1. **Live Space Environment Models (MATLAB Aerospace Toolbox)**:
   * **NRLMSISE-00** orbit-averaged thermospheric density across ECSS Solar Min ($F_{10.7}=70$), Nominal ($140$), and Solar Max ($220$) regimes (with exponential fallback).
   * **IGRF-14** (epoch 2028.42) 3D geomagnetic interpolants resolving both the altitude-dependent South Atlantic Anomaly (SAA) inner proton belt ($|B| < 22.2\,\mu\text{T}$) and outer Van Allen polar electron horns ($L > 3.2$).
2. **High-Precision Numerical Propagation**:
   * `ode113` (`RelTol=1e-9, AbsTol=1e-10`) in J2000 ECI with $J_2 + J_3 + J_4$, co-rotating NRLMSISE-00 drag, smooth $C^1$ conical penumbra SRP, Gauss-variational secular drag work integration, and IAU-2000/2006 ECI→WGS-84 ECEF conversion.
3. **Parametric 2D Orbit Trade Study**:
   * 99-orbit sweep ($400\text{–}650\text{ km} \times 0^\circ\text{–}97.4^\circ$) mapping radiation duty cycle, equatorial VHF coverage, Solar-Min 5-year passive lifetime, and Solar-Max 3-year drag $\Delta v$.
4. **3D Sky Coverage & Monte Carlo GRB Localization Error Budget**:
   * 1,000-pixel Fibonacci celestial sphere with $+80\text{ km}$ atmospheric limb, Sun/Moon exclusion (`OPS-060`), boresight pointing laws, and $k$-fold simultaneous constellation co-viewing (`ARC-060`).
   * 3,000-burst Monte Carlo cosmic GRB population (broken power-law $\log N\text{–}\log P$, Band spectra) with Skinner coded-mask centroiding and exact **3D Fisher Information Matrix Cramér-Rao Lower Bounds (CRLB)** for TDOA constellations.
5. **Multi-Path Alert Latency & RF Link Closure**:
   * Compares a 47-station SVOM-heritage equatorial VHF alert network (137.5 MHz, 600 bps, $+29.8\text{ dB}$ margin at $5^\circ$ mask), commercial **Iridium NEXT SBD/Certus** LEO relay, and S/X-band TT&C store-and-forward.
6. **Automated Verification & Objective MCDA**:
   * 6 automated analytical & literature plausibility benchmarks (*Swift* & *SVOM* calibrated).
   * Zero subjective 1–5 scoring: physical KPI **TOPSIS** across 4 objective weighting schemes (Equal, Shannon Entropy, Science Priority, SmallSat Cost/SWaP) + 10,000-trial Dirichlet Monte Carlo sensitivity analysis.

---

## Repository Structure

```text
.
├── main_mission_analysis.m            # 7-stage master pipeline orchestrator
├── main_tradeoff_study.m              # Backward-compatible entry wrapper
├── CHANGELOG.md                       # Version history (Keep a Changelog)
├── README.md                          # Project documentation
├── config/
│   ├── constants.m                    # WGS-84, EGM2008 (J2/J3/J4), IAU-2006, ECSS margins
│   ├── mission_requirements.m         # Quantitative thresholds & goals (70 mission reqs)
│   ├── build_atmosphere_model.m       # Live NRLMSISE-00 (Solar Min / Nom / Max)
│   ├── ground_stations_config.m       # 5 TT&C stations, 47 equatorial VHF sites, Iridium NEXT
│   └── get_architecture_configs.m     # 6 candidate mission architectures (ARCH-1..ARCH-6)
├── core/
│   ├── kep2cart.m / cart2kep.m        # Vectorized Vallado 5th Ed. state conversions
│   ├── eci2ecef_iau.m                 # Vectorized IAU-2000/2006 ECI -> ECEF
│   ├── ecef2lla_wgs84.m               # Vectorized Bowring WGS-84 geodetic LLA
│   ├── sun_moon_ephemeris.m           # Vectorized Vallado Sun & Moon ECI ephemerides
│   ├── atmosphere_density.m           # Fast log-linear NRLMSISE-00 interpolation
│   └── orbit_propagator.m             # ODE113 propagator with Gauss drag work integration
├── verification/
│   └── verify_mission_analysis.m      # 6 analytical & literature plausibility checks (V-01..V-06)
├── analysis/
│   ├── build_geomagnetic_model.m      # Live IGRF-14 3D gridded interpolant
│   ├── analyze_orbit_trade_space.m    # 99-orbit parametric Altitude x Inclination sweep
│   ├── analyze_radiation_saa.m        # Altitude-dependent SAA + polar electron horns
│   ├── analyze_eclipse_annual.m       # Conical shadow + 365-day Solar Beta (Worst Cold/Hot)
│   ├── analyze_sky_coverage_3d.m      # 3D Fibonacci celestial sphere & >=4-fold co-viewing
│   ├── analyze_localization_yield.m   # 3,000-GRB Monte Carlo SNR & 3D CRLB localization
│   ├── analyze_comms_latency.m        # VHF link budget + VHF/Iridium/TT&C alert latency CDF
│   ├── analyze_lifetime_deltav.m      # Bounded Solar-Min lifetime + Solar-Max Delta-V & prop
│   └── evaluate_tradeoff_study.m      # Screening + TOPSIS (4 weight sets) + 10k Dirichlet MC
├── plots/                             # 250-DPI light-theme TUM academic figures
├── export/
│   └── export_deliverables.m          # Exports JSON, CSV, Markdown report & LaTeX tables
└── results/                           # Generated figures (.png), tables (.tex), JSON, CSV, MD
```

---

## Quick Start

### Requirements
* **MATLAB R2022b or later** (validated on **MATLAB R2026a**)
* **Aerospace Toolbox** recommended for live `atmosnrlmsise00`, `igrfmagm` (IGRF-14), and `dcmeci2ecef` (graceful analytical fallbacks are built in if Aerospace Toolbox is unavailable)

### Execution
```matlab
main_mission_analysis
```
Runtime is **~65–70 seconds** end-to-end. All figures, CSV/JSON subsystem handoffs, and LaTeX tables are automatically written to `results/`.

---

## Baseline Results Summary (v2.0)

| Code | Architecture | Orbit | Mass [kg] | Cost [M$] | Localized <=10' [/yr] | r90 (SNR>=8) | Duty [%] | VHF / Iridium <=30 s | Delta-V [m/s] | Gates | MC Win Prob |
| :--- | :--- | :--- | ---: | ---: | ---: | ---: | ---: | :---: | ---: | :---: | ---: |
| **ARCH-1** | **Coded-Mask SmallSat (SRR)** | **535 km / 28.5°** | **75** | **16.5** | **41.8** | **2.7'** | **84.5%** | **92.5% / 91.8%** | **188.8** | **7/7** | **82.9%** |
| ARCH-2 | Coded-Mask Monolith (Flagship) | 600 km / 29.0° | 850 | 180.0 | 83.5 | 2.0' | 81.1% | 95.0% / 91.9% | 213.3 | 7/7 | 17.1% |
| ARCH-3 | TDOA Constellation (9-Sat) | 535 km / 28.5° | 216 | 32.0 | 17.9 | 67.6' | 96.0% | 100.0% / 67.1% | 188.3 | 5/7 | 0.0% |
| ARCH-4 | Lobster-Eye Soft X-Ray (WXT) | 550 km / 29.0° | 450 | 75.0 | 9.5 | 1.3' | 83.8% | 92.8% / 90.2% | 144.0 | 6/7 | 0.0% |
| ARCH-5 | Count-Rate Dome (GECAM) | 550 km / 29.0° | 300 | 28.0 | 0.0 | 328.7' | 96.0% | 99.9% / 93.4% | 172.7 | 5/7 | 0.0% |
| ARCH-6 | SSO SmallSat (Orbit Ref.) | 535 km / 97.5° | 75 | 15.0 | 30.8 | 2.8' | 58.0% | 39.7% / 91.8% | 185.6 | 4/7 | 0.0% |

**Selected Baseline:** `ARCH-1: Compact Coded-Mask SmallSat (535 km, 28.5°)` — passes all 7/7 mandatory requirement gates, fits the SmallSat SRR budget ($\le 80\text{ kg}$, $<\$20\text{M}$), and achieves an **82.9%** Rank-1 win probability over 10,000 Dirichlet weight-space trials.

---

## Subsystem Data Handoff

Downstream subsystems ingest consistent, verified boundary conditions directly from [`results/Subsystem_Inputs.json`](results/Subsystem_Inputs.json):
* **Power & Thermal (Simscape):** Worst cold/hot eclipse durations ($35.65\text{ min}$ / $27.21\text{ min}$), 1-year $\beta(t)$ bounds, sunlight fraction.
* **Propulsion:** Complete ECSS $\Delta v$ breakdown (`188.8 m/s`, `6.4 kg` green monopropellant including $+10\%$ margin & $+2\%$ residual) and ESA ESSB-ST-U-007 perigee-lowering disposal.
* **Telecom & OBDH:** VHF link margin ($+29.8\text{ dB}$), alert latency percentiles, daily S/X-band downlink capacity, max blackout gap.
* **Payload & ConOps:** Annual localized yield, $r_{90}$ error distribution, IGRF-14 SAA/polar blanking duty cycle, and relative proton dose index.
