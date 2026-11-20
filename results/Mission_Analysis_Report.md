# TUM Space Mission Design (WS 2026/27) — GRB Alert Mission Analysis Report (v2.0)

Generated automatically on 2026-11-20 12:04 using MATLAB R2026a + Aerospace Toolbox (NRLMSISE-00, IGRF-14, IAU-2000/2006).

## 1. Automated Verification & Literature Plausibility Checks (6/6 PASSED)

| ID | Check | Numerical Output | Analytical / Literature Benchmark | Status |
| :--- | :--- | :--- | :--- | :--- |
| V-01 | Two-Body Energy & Angular Momentum Conservation (10 orbits) | dE/E=9.26e-10, dH/H=4.63e-10 | < 1.0e-8 (analytical invariant) | **PASS** |
| V-02 | J2 Secular RAAN Precession vs Analytical (500 km SSO) | 0.9903 deg/day (err=0.47%) | 0.9857 deg/day (SSO=0.9856) | **PASS** |
| V-03 | Conical Max Eclipse Duration at Beta=0 (600 km) vs Hand Calc | 34.83 min (err=1.84%) | 35.49 min (T/pi*asin(Re/a)) | **PASS** |
| V-04 | Gauss Drag Work Decay vs Analytical Circular Rate (500 km) | 19016 m/yr (err=3.58%) | 19721 m/yr (NRLMSISE-00 Nom) | **PASS** |
| V-05 | Literature Benchmark: Swift LEO (600 km, 20.6 deg) | SAA=14.5%, Occ=31.1% | Lit: SAA ~9-15%, Occ ~30-32% (Gehrels 2004) | **PASS** |
| V-06 | Literature Benchmark: SVOM VHF Network (625 km, 29.0 deg) | Cov=95.7%, Med=9.4s, <=30s=96.2% | Lit: Cov ~93%, Med 8.9s, >=66% <=30s (arXiv:2604.24263) | **PASS** |

## 2. Architecture Screening & Quantitative Comparison

| Code | Architecture | Orbit | Mass [kg] | Cost [M$] | Yield <=10' [/yr] | r90 (SNR>=8) | Duty [%] | VHF <=30s | Iridium <=30s | Delta-V [m/s] | Screening |
| :--- | :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| ARCH-1 | Coded-Mask SmallSat | 535km/28.5° | 75 | 16.5 | 41.8 | 2.7' | 84.5% | 92.5% | 91.8% | 188.8 | PASS (All 7 Gates) |
| ARCH-2 | Coded-Mask Monolith | 600km/29.0° | 850 | 180.0 | 83.5 | 2.0' | 81.1% | 95.0% | 91.9% | 213.3 | PASS (All 7 Gates) |
| ARCH-3 | TDOA Constellation (9x) | 535km/28.5° | 216 | 32.0 | 17.9 | 67.6' | 96.0% | 100.0% | 67.1% | 188.3 | FAIL: Yield 17.9 < 40/yr; r90 67.6' > 10' |
| ARCH-4 | Lobster-Eye (Soft-X) | 550km/29.0° | 450 | 75.0 | 9.5 | 1.3' | 83.8% | 92.8% | 90.2% | 144.0 | FAIL: Yield 9.5 < 40/yr |
| ARCH-5 | Count-Rate Dome (GECAM) | 550km/29.0° | 300 | 28.0 | 0.0 | 328.7' | 96.0% | 99.9% | 93.4% | 172.7 | FAIL: Yield 0.0 < 40/yr; r90 328.7' > 10' |
| ARCH-6 | SSO SmallSat (97.5 deg) | 535km/97.5° | 75 | 15.0 | 30.8 | 2.8' | 58.0% | 39.7% | 91.8% | 185.6 | FAIL: Yield 30.8 < 40/yr; Duty 58.0% < 60%; Inc 97.5 deg > 30 deg |

## 3. Recommended Baseline

**Selected Architecture:** `Compact Coded-Mask SmallSat (SRR Candidate)`

Feasible 2D Orbit Corridor points found: 16 / 99 tested (Altitude 400–650 km x Inclination 0–97.4 deg).
