# Project Context: GRB Alert Mission (TUM Space Mission Design, WS 2026/27)

_Last updated: 2026-11-25_

## 1. What this project is

Course project for **Space Mission Design** (Chair of Spacecraft Systems, TUM), Project 2:
*Space System for Gamma-Ray Burst Alert*. The team designs a post-*Swift* mission that
detects GRBs, localizes them to ≤ 10 arcmin and sends alerts to the ground within ~30 s.

The work follows the course report guide (`Lectures/Space Mission Design - Report Guide WS26_27.pdf`).
The rule from that guide that shapes most of the analysis: every trade criterion must come from a
requirement, carry a unit, and be computed or cited. Subjective 1–5 scores and team-chosen weights
are not accepted.

**Current baseline:** a single SmallSat carrying a coded-mask hard X-ray imager, in a
535 km / 28.5° circular LEO (MATLAB code `ARCH-1`, trade-off code `A1`).

## 2. Folder map

| Folder | Content | Status |
| :--- | :--- | :--- |
| `Lectures/` | Course slides, project brief, report guide | Reference |
| `Papers/` | Fermi/GBM (Meegan 2009), HERMES Pathfinder, SMAD book, TESS afterglows, GBM background ML | Reference |
| `State of the art/` | Reference mission dossiers (Fermi, HERMES Pathfinder), `.docx` | Done |
| `Requirement analysis/` | SysML model (`GRB_Alert_Mission.sysml/.xmi/.xml`), requirements workbook `GRB_mission_analysis.xlsx`, SRR LaTeX (latest `SRR_main_v07.tex/.pdf`), helper scripts `req2tex.py`, `srr24*.py` | SRR delivered; requirement changes pending (see §6) |
| `Trade-off/` | Localization-architecture trade (T-1): `tradeoff_model.py` → `generated/*.tex` + `results.csv`, LaTeX section `tradeoff_section.tex`, MATLAB check `verification/check_detection_rate.m` | Edited 2026-11-25 (15:12–15:18) |
| `MATLAB_Mission_Analysis/` | Mission-analysis suite v2.0 (own git repo, see §3) | v2.0.0 tagged |
| `AI Engineering Log.xlsx` | Log of AI-assisted work | Ongoing |

## 3. Mission Analysis: what changed

`MATLAB_Mission_Analysis/` is a separate git repository
(remote `github.com/sauceta/grb-mission-analysis-matlab`, branch `main`, tag `v2.0.0`).
It has **one commit**, `41ce346` "Initial commit: GRB Alert Mission Analysis Suite v2.0"
(2026-11-20). The earlier versions are recorded only in `CHANGELOG.md`.

### Version history (from CHANGELOG)

| Version | Date | Summary |
| :--- | :--- | :--- |
| 1.0.0 | 2026-11-13 | Prototype: 3 architectures, 3-day `ode45` (J2, J3, exponential drag), cylindrical eclipse, polygon SAA, ground contacts, Δv budget |
| 1.1.0 | 2026-11-16 | 5 architectures, 41-station VHF network, alert latency CDF, burst yield, ESA 5-yr lifetime, AHP scoring. Fixed drag-decay bug that gave negative Δv |
| **2.0.0** | **2026-11-20** | **Full rebuild**, details below |

### v2.0.0 changes

**Physics models**
- Propagator: `ode45` → `ode113` (RelTol 1e-9), J2+J3+J4, NRLMSISE-00 drag, conical-penumbra SRP, Gauss-variational drag work.
- Atmosphere: NRLMSISE-00 at solar min / nominal / max (F10.7 = 70 / 140 / 220), exponential fallback.
- Radiation: IGRF-14 (epoch 2028.42) for the SAA (|B| < 22.2 µT) and polar electron horns (L > 3.2). Replaces the polygon SAA.
- Frames: vectorized IAU-2000/2006 ECI→ECEF and Bowring WGS-84.

**New analyses**
- 99-point orbit trade map (400–650 km × 0–97.4°): radiation duty cycle, VHF coverage, 5-yr lifetime, Δv. 16/99 points are feasible.
- Full-year β-angle and conical eclipse giving worst cold / hot cases for Power and Thermal.
- 3D sky coverage (1000-pixel Fibonacci sphere, Earth limb +80 km, Sun 35° / Moon 10° exclusion).
- 3000-burst Monte Carlo GRB population with coded-mask SNR/centroiding and Fisher-matrix CRLB for TDOA.
- Alert paths: 47-station equatorial VHF (137.5 MHz, 600 bps), Iridium NEXT relay, S/X-band TT&C.
- Trade-off: 7-gate requirement screening + TOPSIS with 4 weight sets + 10 000-trial Dirichlet sensitivity. **The AHP 1–5 scoring was removed** because the report guide does not accept it.
- Verification suite: 6 checks (V-01…V-06), all pass, including Swift and SVOM benchmarks.
- Exporters: `Subsystem_Inputs.json`, `Mission_Analysis_Summary.csv`, `Mission_Analysis_Report.md`, LaTeX tables.

**Trade space:** expanded to 6 architectures, including the SRR candidate `ARCH-1` and an SSO reference (`ARCH-6`) that isolates the orbit penalty.

**Bug fixes:** coded-mask open fraction was applied twice to A_eff; lifetime/Δv cases were swapped (now passive lifetime at solar **min**, drag Δv at solar **max**); dark-mode figure export and TeX warnings.

### Working-tree state (2026-11-25)

- All tracked source and result files match commit `41ce346` (no content edits since v2.0.0). File timestamps show 14:59 today, which points to a re-copy or re-run rather than edits.
- `.gitignore` is **deleted** from the working tree.
- Because of that, `results/Mission_Analysis_v2_Results.mat` (8.9 MB) now appears as untracked. It was ignored on purpose (regenerable).
- **Action:** restore with `git checkout -- .gitignore` before the next commit, so the `.mat` file isn't committed by mistake.

## 4. Mission Analysis key results (v2.0)

| Code | Architecture | Orbit | Mass [kg] | Cost [M$] | Localized ≤10′ [/yr] | r90 | Duty | VHF ≤30 s | Gates | MC win |
| :--- | :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | :---: | ---: |
| **ARCH-1** | **Coded-mask SmallSat** | **535 km / 28.5°** | **75** | **16.5** | **41.8** | **2.7′** | **84.5%** | **92.5%** | **7/7** | **82.9%** |
| ARCH-2 | Coded-mask monolith | 600 / 29.0° | 850 | 180 | 83.5 | 2.0′ | 81.1% | 95.0% | 7/7 | 17.1% |
| ARCH-3 | TDOA constellation (9) | 535 / 28.5° | 216 | 32 | 17.9 | 67.6′ | 96.0% | 100% | 5/7 | 0% |
| ARCH-4 | Lobster-eye soft X | 550 / 29.0° | 450 | 75 | 9.5 | 1.3′ | 83.8% | 92.8% | 6/7 | 0% |
| ARCH-5 | Count-rate dome | 550 / 29.0° | 300 | 28 | 0.0 | 328.7′ | 96.0% | 99.9% | 5/7 | 0% |
| ARCH-6 | SSO SmallSat | 535 / 97.5° | 75 | 15 | 30.8 | 2.8′ | 58.0% | 39.7% | 4/7 | 0% |

Subsystem handoff values for ARCH-1 (from `results/Subsystem_Inputs.json`):
- Eclipse, worst cold / hot: 35.65 min / 27.21 min
- Δv: 188.8 m/s, 6.4 kg green monopropellant (+10% margin, +2% residual)
- VHF link margin: +29.8 dB at 5° elevation

Run the suite with `main_mission_analysis` in MATLAB R2022b+ (tested on R2026a). It takes about 70 s, and Aerospace Toolbox is recommended.

## 5. How the pieces connect

```
Requirements (xlsx / SRR) ──► MATLAB config/mission_requirements.m (single source of truth)
                         └──► Trade-off/tradeoff_model.py (inputs table)

MATLAB v2.0 (ARCH-1) ──► eta_eff = 0.74, VHF ≤30 s = 92.5 % ──► tradeoff_model.py inputs
MATLAB analyze_localization_yield.m (burst population) ──► Trade-off/verification/check_detection_rate.m
Trade-off generated/*.tex ──► Overleaf report section
MATLAB results/tables/*.tex ──► Overleaf mission-analysis section
```

If either side changes, re-run `tradeoff_model.py` and re-upload `generated/*.tex` to Overleaf.

## 6. Open issues and inconsistencies

The MATLAB suite (2026-11-20) and the newer Trade-off section (2026-11-25) don't fully agree yet:

1. **Trade method.** MATLAB ranks architectures with TOPSIS and four weight sets. `tradeoff_section.tex` says "no weighted scoring table is used" and picks by lowest cost per usefully localized burst. Decide which method the report uses, or present TOPSIS only as a cross-check.
2. **Payload mass PHY-010.** MATLAB uses 25 kg. The trade-off uses the 10 kg TBC and asks to raise it (A1 needs 21.8 kg incl. margin).
3. **Background ENV-010.** MATLAB uses 1.5 cts/cm²/s. The trade-off uses 3.0.
4. **Detection yield.** MATLAB ARCH-1 gives 41.8 localized GRB/yr. The trade-off A1 gives 32.5 (flow-down), and the population check gives only **23.5/yr**, below MIS-020 (40/yr). The payload chapter must size detector area and FoV together.
5. **Cost and mass.** MATLAB ARCH-1: 75 kg, $16.5M. Trade-off A1: 86.5 kg launch mass, $22.7M (above the $20M SmallSat cap).
6. **Requirement updates proposed by the trade-off:**
   - Raise PHY-010.
   - Revise PER-040 and PER-065 together.
   - Confirm ENV-010 with a background model.
   - Rewrite PER-010.
   - Delete ARC-050…070 (constellation dropped).
   - Check the ENV-050 (i ≤ 30°) orbit against what rideshare services offer.

   These are not yet reflected in `mission_requirements.m` or the SRR.
7. **Minor:** the header of `main_mission_analysis.m` says 45 VHF stations, but the README and CHANGELOG say 47.
8. **Repo hygiene:** `.gitignore` is deleted (see §3).

## 7. Next steps (pending)

- Downstream trades: T-2 orbit (largely covered by MATLAB), T-3 alert link, T-4 detector, T-5 launch.
- Payload chapter: size the camera against MIS-020 using the burst-population model.
- Bring the MATLAB requirements and ARCH-1 parameters in line with the trade-off results, then re-run and tag v2.1.
