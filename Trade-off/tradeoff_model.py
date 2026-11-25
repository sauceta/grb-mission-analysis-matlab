"""
System-level architecture trade-off: GRB localization technique.
TUM Space Mission Design WS26/27 - Gamma-Ray Burst Alert mission.

Version 2: the coded-mask option is sized from first principles against the SRR
thresholds (no scaling from an existing instrument).

Pure Python (standard library only). Run:
    python tradeoff_model.py
Writes into ./generated/ :
    screening.tex     stage-1 go/no-go screening of localization techniques
    mask_design.tex   first-principles coded-mask design for each mask alternative
    trade_matrix.tex  stage-2 trade-off matrix (alternatives x criteria)
    sensitivity.tex   sensitivity / decision-flip table
    inputs.tex        every input with its source
    results.csv       every computed number

Decision rule (no team-chosen weights, Report Guide p.4):
  1. Reject any alternative that misses a threshold of MIS-020, MIS-030, MIS-040,
     PER-065 or the nominal figure of merit N_u >= 30/yr (SRR 2.3).
  2. Among the rest, select the lowest cost per usefully localized burst.
"""
import csv
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "generated")
os.makedirs(OUT, exist_ok=True)

KEV_PER_ERG = 1.0 / 1.602176634e-9

# ----------------------------------------------------------------------------
# 1. INPUTS  (value, unit, source)
# ----------------------------------------------------------------------------
P = {
    # --- SRR thresholds that size the coded mask ------------------------------
    "F_req":      (2.5e-8, "erg/cm2/s", "PER-040 threshold: 1-s peak flux, 5-50 keV"),
    "F_goal":     (1.0e-8, "erg/cm2/s", "PER-040 goal"),
    "E1":         (5.0,   "keV",  "PER-040 band, lower edge"),
    "E2":         (50.0,  "keV",  "PER-040 band, upper edge"),
    "t_int":      (1.0,   "s",    "PER-040: 1-s peak flux"),
    "snr_trig":   (6.5,   "-",    "PER-100: alert threshold"),
    "snr_loc":    (8.0,   "-",    "PER-010: reference SNR"),
    "req_r90":    (10.0,  "arcmin","MIS-030 / PER-010"),
    "sys_loc":    (2.5,   "arcmin","PER-020: systematic allocation"),
    "b_bkg":      (3.0,   "cts/cm2/s","ENV-010: design background count rate"),
    "req_fovEta": (0.75,  "sr",   "PER-065"),
    "m_pl_max":   (10.0,  "kg",   "PHY-010 threshold (SRR, TBC)"),
    "p_pl_max":   (15.0,  "W",    "PHY-020 threshold (SRR, TBC)"),
    "req_Ndet":   (40.0,  "GRB/yr","MIS-020"),
    "req_lat_pct":(66.0,  "%",    "MIS-040: >= 66% of alerts within 30 s"),
    "req_Nu":     (30.0,  "GRB/yr","FoM nominal tier (SRR 2.3)"),
    "years":      (2.0,   "yr",   "MIS-010"),
    # --- Physics / design inputs for the coded mask ----------------------------
    "gamma_ph":   (1.0,   "-",    "Band1993: low-energy photon index alpha ~ -1 (spectrum N(E) ~ E^-1)"),
    "rho":        (0.5,   "-",    "Braga2019: open fraction 0.5 maximizes SNR for background-dominated masks"),
    "eps":        (0.8,   "-",    "ASSUMPTION: CdTe 2 mm full-energy efficiency over 5-50 keV"),
    "k_loc":      (1.5,   "-",    "ASSUMPTION [CHECK Skinner2008/Braga2019]: r90 = k_loc x theta_res / SNR"),
    "r_md":       (1.25,  "-",    "Barthelmy2005: BAT mask element / pixel = 5 mm / 4 mm"),
    "eta_eff":    (0.74,  "-",    "Team orbit simulation (MATLAB_Mission_Analysis v2.0, ARCH-1, 535 km/28.5 deg)"),
    "rho_cdte":   (5.85,  "g/cm3","NIST: CdTe density"),
    "t_det":      (0.2,   "cm",   "ASSUMPTION: 2 mm CdTe (absorbs > 90% up to 50 keV)"),
    "k_fee":      (2.5,   "-",    "ASSUMPTION: detector module mass = 2.5 x crystal mass (ASICs, boards, cold plate)"),
    "rho_w":      (19.3,  "g/cm3","NIST: tungsten density"),
    "t_mask":     (0.1,   "cm",   "ASSUMPTION: 1 mm W mask (opaque over 5-50 keV)"),
    "k_supp":     (1.5,   "-",    "ASSUMPTION: mask support frame = 50% of mask mass"),
    "sig_shield": (1.5,   "g/cm2","ASSUMPTION: graded Pb/Sn/Cu side and rear shield areal density"),
    "m_dpu":      (3.0,   "kg",   "ASSUMPTION: data processing unit for on-board imaging and trigger"),
    "p_ch":       (0.5e-3,"W",    "ASSUMPTION: front-end power per pixel channel"),
    "p_dpu":      (5.0,   "W",    "ASSUMPTION: data processing unit power"),
    "mar_pl":     (0.20,  "-",    "ESA margin philosophy [SRR 46]: 20% for new developments"),
    "mar_sys":    (0.20,  "-",    "DES-010: 20% system-level mass margin"),
    "dry_per_pl": (3.3,   "-",    "SMAD Table 10-6 p.312: dry mass = 3.3 x payload (range 2-7)"),
    "beta":       (1.0,   "-",    "ASSUMPTION: integral logN-logS slope near threshold (0.8-1.5; 1.5 = Euclidean)"),
    "lat_pct_A":  (92.5,  "%",    "Team orbit simulation (MATLAB v2.0, ARCH-1): VHF alerts within 30 s"),
    # --- Triangulation constellation ------------------------------------------
    "tri_k":      (2.4,   "deg/ms","Fiore2020 [SRR 16]: sigma = 2.4 deg x sigma_t(ms)/sqrt(N-3), baseline 7000 km"),
    "sig_t_opt":  (0.34,  "ms",   "DERIVED from CAMELOT ~20 arcmin with 9 CubeSats (Werner2018 [SRR 22])"),
    "sig_t_pes":  (1.80,  "ms",   "DERIVED from HERMES Pathfinder ~2.5 deg with 6 units (Fiore2020 [SRR 16])"),
    "fov_unit":   (5.20,  "sr",   "Ghirlanda2024 Table 1: HERMES S-mode FoV per unit"),
    "earth_vis":  (0.70,  "-",    "DERIVED: Earth blocks 3.83 sr (30%) of the sky at 550 km"),
    "m_unit":     (6.0,   "kg",   "Ghirlanda2024 Sec.2: HERMES 3U unit mass"),
    "m_pl_unit":  (1.55,  "kg",   "Fiore2024 (arXiv:2409.00989): HERMES-TP payload mass"),
    "N_det_B":    (214.0, "GRB/yr","Ghirlanda2024 Table 2: HERMES Pathfinder 195 long + 19 short"),
    "f_loc_B":    (0.5,   "-",    "ASSUMPTION: fleet sized for the median burst -> half reach r90 <= 10'"),
    "lat_pct_B":  (0.0,   "%",    "Fiore2024 (arXiv:2409.00989): trigger messages within 30 min -> none within 30 s"),
    "planes_B":   (2,     "-",    "ARC-070 threshold: >= 2 orbital planes"),
    # --- Cost inputs ----------------------------------------------------------
    "cpi_2000":   (172.2, "-",    "BLS CPI-U annual average 2000"),
    "cpi_2018":   (251.1, "-",    "BLS CPI-U annual average 2018"),
    "cpi_2024":   (313.7, "-",    "BLS CPI-U annual average 2024"),
    "eur_usd_18": (1.181, "$/EUR","ECB 2018 average reference rate"),
    "hermes_sp":  (3.434, "MEUR2018","CORDIS 821896: HERMES-SP total, dev + 3 flight units, no launch/ops"),
    "nre_B":      (5.0,   "M$2024","ASSUMPTION: constellation-level NRE, NASA Astrophysics CubeSat line <$5M (Garcia2021)"),
    "ls_B":       (0.85,  "-",    "SMAD Sec.20.4.4 p.809: learning slope 85% for >50 units"),
    "pl_cost_f":  (0.4,   "-",    "SMAD Table 20-6 p.797 (SSCM): payload = 0.4 x bus cost"),
    "launch_base":(0.35,  "M$",   "SpaceX rideshare 2026 list price: $350k up to 50 kg"),
    "launch_kg":  (7000.0,"$/kg", "SpaceX rideshare 2026 list price: $7,000/kg above 50 kg"),
}
V = {k: v[0] for k, v in P.items()}

R90_TO_SIGMA = math.sqrt(2.0 * math.log(10.0))  # 2.146: r90 of a circular 2-D Gaussian


# ----------------------------------------------------------------------------
# 2. MODELS
# ----------------------------------------------------------------------------
def photon_flux(F_erg, v):
    """Energy flux [erg/cm2/s] in E1-E2 -> photon flux [ph/cm2/s] for N(E) ~ E^-gamma (gamma = 1)."""
    F_kev = F_erg * KEV_PER_ERG
    return F_kev / (v["E2"] - v["E1"]) * math.log(v["E2"] / v["E1"])


def snr_mask(P_ph, A_det, v):
    """Imaging SNR of a coded mask with open fraction rho (balanced correlation decoding):
       SNR = sqrt(rho(1-rho)) eps P sqrt(A t) / sqrt(b + (1-rho) eps P)."""
    rho, eps, t, b = v["rho"], v["eps"], v["t_int"], v["b_bkg"]
    return math.sqrt(rho * (1 - rho)) * eps * P_ph * math.sqrt(A_det * t) / math.sqrt(b + (1 - rho) * eps * P_ph)


def area_for_snr(P_ph, snr, v):
    rho, eps, t, b = v["rho"], v["eps"], v["t_int"], v["b_bkg"]
    return (snr * math.sqrt(b + (1 - rho) * eps * P_ph) / (math.sqrt(rho * (1 - rho)) * eps * P_ph)) ** 2 / t


def flux_limit(A_det, v):
    """Photon flux that gives SNR = snr_trig on detector area A_det (bisection)."""
    lo, hi = 1e-4, 1e3
    for _ in range(200):
        mid = math.sqrt(lo * hi)
        if snr_mask(mid, A_det, v) < v["snr_trig"]:
            lo = mid
        else:
            hi = mid
    return hi


def mask_geometry(v):
    """Field of view from PER-065 and angular resolution from PER-010/020."""
    omega = v["req_fovEta"] / v["eta_eff"]                      # half-coded FoV needed [sr]
    alpha = math.asin(math.sqrt(math.sin(omega / 4.0)))         # square FoV: Omega = 4 asin(sin^2 a)
    stat_max = math.sqrt(v["req_r90"] ** 2 - v["sys_loc"] ** 2)  # arcmin
    theta = stat_max * v["snr_loc"] / v["k_loc"]                # max angular resolution FWHM [arcmin]
    return omega, alpha, theta


def mask_mass_power(A_det, v):
    omega, alpha, theta = mask_geometry(v)
    D = math.sqrt(A_det)                                        # cm, square detector = mask
    f = D / (2.0 * math.tan(alpha))                             # mask-detector distance [cm]
    d = math.radians(theta / 60.0) * f / math.sqrt(1 + v["r_md"] ** 2)   # pixel pitch [cm]
    n_pix = (D / d) ** 2
    m_det = v["rho_cdte"] * v["t_det"] * A_det * v["k_fee"] / 1000.0
    m_mask = (1 - v["rho"]) * A_det * v["rho_w"] * v["t_mask"] * v["k_supp"] / 1000.0
    m_shield = v["sig_shield"] * (4 * D * f + D * D) / 1000.0
    m_cbe = m_det + m_mask + m_shield + v["m_dpu"]
    m_pl = m_cbe * (1 + v["mar_pl"])
    p_pl = n_pix * v["p_ch"] + v["p_dpu"]
    return dict(D=D, f=f, d=d, n_pix=n_pix, m_det=m_det, m_mask=m_mask, m_shield=m_shield,
                m_cbe=m_cbe, m_pl=m_pl, p_pl=p_pl, omega=omega, alpha=alpha, theta=theta)


def sscm_cost_musd2024(bus_dry_kg, v):
    """SMAD Table 20-6 (SSCM), FY00 $K -> M$ 2024.  Valid for bus dry mass 20-400 kg."""
    bus = 781.0 + 26.1 * bus_dry_kg ** 1.261
    sc = bus * (1.0 + v["pl_cost_f"])
    total = sc * (1.0 + 0.139 + 0.229 + 0.066 + 0.061)
    return total / 1000.0 * v["cpi_2024"] / v["cpi_2000"], (20.0 <= bus_dry_kg <= 400.0)


def launch_musd(mass_kg, v, n_launch=1):
    per = mass_kg / n_launch
    return n_launch * (v["launch_base"] + v["launch_kg"] * max(0.0, per - 50.0) / 1e6)


def coded_mask(name, v, F_design=None, m_pl_cap=None):
    """Size a coded-mask camera either to a flux requirement or to a payload-mass cap."""
    if m_pl_cap is None:
        P_design = photon_flux(F_design, v)
        A = area_for_snr(P_design, v["snr_trig"], v)
    else:
        lo, hi = 1.0, 1e5                                       # find area whose payload mass = cap
        for _ in range(200):
            mid = 0.5 * (lo + hi)
            if mask_mass_power(mid, v)["m_pl"] > m_pl_cap:
                hi = mid
            else:
                lo = mid
        A = lo
    g = mask_mass_power(A, v)
    P_lim = flux_limit(A, v)
    P_req = photon_flux(v["F_req"], v)
    fov_eta = g["omega"] * v["eta_eff"]
    b = v["beta"]
    # SRR flow-down: a camera exactly at PER-040 and PER-065 detects the MIS-020 rate.
    n_det = v["req_Ndet"] * (P_lim / P_req) ** (-b) * fov_eta / v["req_fovEta"]
    r90 = math.hypot(v["k_loc"] * g["theta"] / v["snr_loc"], v["sys_loc"])
    snr10 = v["k_loc"] * g["theta"] / math.sqrt(v["req_r90"] ** 2 - v["sys_loc"] ** 2)
    f_loc = min(1.0, (snr10 / v["snr_trig"]) ** (-b))
    n_u = n_det * f_loc
    m_dry = v["dry_per_pl"] * g["m_pl"] * (1 + v["mar_sys"])
    cost, in_range = sscm_cost_musd2024(m_dry - g["m_pl"], v)
    cost += launch_musd(m_dry, v)
    return dict(name=name, kind="Coded-mask imager, 1 spacecraft", n_sc=1, area=A,
                a_eff=v["rho"] * v["eps"] * A, F_lim=P_lim / P_req * v["F_req"],
                m_pl=g["m_pl"], p_pl=g["p_pl"], m_launch=m_dry, fov_eta=fov_eta, r90=r90,
                n_det=n_det, lat_pct=v["lat_pct_A"], n_u=n_u,
                cost=cost, cpb=cost / (n_u * v["years"]) if n_u > 0 else float("inf"),
                model_ok=in_range, evidence="Technique flown (Swift/BAT, INTEGRAL)", geo=g)


def triangulation(name, sig_t, v, n_fleet=None, latency_ok=False):
    sig_req_deg = v["req_r90"] / R90_TO_SIGMA / 60.0
    n_vis_req = 3 + math.ceil((v["tri_k"] * sig_t / sig_req_deg) ** 2)
    f_see = v["earth_vis"] * v["fov_unit"] / (4.0 * math.pi)
    if n_fleet is None:
        n_fleet = math.ceil(n_vis_req / f_see)
    n_vis = max(4, math.floor(n_fleet * f_see))
    sigma_deg = v["tri_k"] * sig_t / math.sqrt(n_vis - 3)
    r90 = sigma_deg * 60.0 * R90_TO_SIGMA
    lat_pct = v["lat_pct_A"] if latency_ok else v["lat_pct_B"]
    f_loc = v["f_loc_B"] if r90 <= v["req_r90"] + 1e-9 else 0.0
    f_lat = 1.0 if latency_ok else 0.0      # 30 min > 20 min usefulness limit
    n_u = v["N_det_B"] * f_loc * f_lat
    tfu = v["hermes_sp"] / 3.0 * v["eur_usd_18"] * v["cpi_2024"] / v["cpi_2018"]
    B = 1.0 - math.log(1.0 / v["ls_B"]) / math.log(2.0)
    m = n_fleet * v["m_unit"]
    cost = v["nre_B"] + tfu * n_fleet ** B + launch_musd(m, v, int(v["planes_B"]))
    return dict(name=name, kind="Timing triangulation, %d CubeSats" % n_fleet, n_sc=n_fleet,
                area=float("nan"), a_eff=float("nan"), F_lim=float("nan"),
                m_pl=v["m_pl_unit"], p_pl=float("nan"), m_launch=m, fov_eta=float("nan"),
                r90=r90, n_det=v["N_det_B"], lat_pct=lat_pct, n_u=n_u,
                cost=cost, cpb=cost / (n_u * v["years"]) if n_u > 0 else float("inf"),
                model_ok="analogy (SSCM not valid below 20 kg bus)", n_vis=n_vis,
                evidence="Not demonstrated in orbit" if not latency_ok else
                         "Not demonstrated; on-board ISL processing ASSUMED")


TOL = 1e-6


def compliance(a, v):
    c = {
        "MIS-030": a["r90"] <= v["req_r90"] + TOL,
        "MIS-020": a["n_det"] >= v["req_Ndet"] - TOL,
        "MIS-040": a["lat_pct"] >= v["req_lat_pct"],
        "PER-065": (a["fov_eta"] >= v["req_fovEta"] - TOL) if not math.isnan(a["fov_eta"]) else True,
        "FoM":     a["n_u"] >= v["req_Nu"] - TOL,
        "PHY-010": a["m_pl"] <= v["m_pl_max"] + TOL,
        "PHY-020": (a["p_pl"] <= v["p_pl_max"]) if not math.isnan(a["p_pl"]) else True,
    }
    # PHY-010 / PHY-020 are [TBC] values: reported, not used to reject.
    c["pass"] = all(c[k] for k in ("MIS-030", "MIS-020", "MIS-040", "PER-065", "FoM"))
    return c


def alternatives(v):
    return [
        coded_mask("A1", v, F_design=v["F_req"]),
        coded_mask("A2", v, F_design=v["F_goal"]),
        coded_mask("A0", v, m_pl_cap=v["m_pl_max"]),
        triangulation("B1", v["sig_t_opt"], v),
        triangulation("B0", v["sig_t_pes"], v, n_fleet=6),
    ]


def decide(alts, v):
    ok = [a for a in alts if compliance(a, v)["pass"]]
    return min(ok, key=lambda a: a["cpb"])["name"] if ok else "none"


def cxb_background(v, g):
    """Plausibility check of ENV-010: cosmic X-ray background through the open mask.
       Gruber et al. 1999 fit below 60 keV: I(E) = 7.877 E^-0.29 exp(-E/41.13) keV/(cm2 s sr keV)."""
    n, s = 2000, 0.0
    h = (v["E2"] - v["E1"]) / n
    for i in range(n):
        E = v["E1"] + (i + 0.5) * h
        s += 7.877 * E ** -0.29 * math.exp(-E / 41.13) / E * h      # ph/(cm2 s sr)
    return v["eps"] * v["rho"] * g["omega"] * s, s


# ----------------------------------------------------------------------------
# 3. OUTPUT
# ----------------------------------------------------------------------------
def f(x, nd=1):
    if isinstance(x, float) and math.isnan(x):
        return "--"
    if isinstance(x, float) and math.isinf(x):
        return "$\\infty$"
    return f"{x:,.{nd}f}".replace(",", "\\,")


def mark(ok):
    return "\\cellcolor{passc}" if ok else "\\cellcolor{failc}"


NAMES = {"A1": "A1: mask at PER-040 threshold", "A2": "A2: mask at PER-040 goal",
         "A0": "A0: mask within PHY-010", "B1": "B1: triangulation, sized",
         "B0": "B0: HERMES-class, 6 s/c"}


def write_screening():
    rows = [
        ("Coded-aperture mask", "Swift/BAT, INTEGRAL, SVOM",
         "1--4$'$ (BAT)", "15--150 (BAT)", True,
         "Arcminute localization flown; carried to stage 2"),
        ("Timing triangulation", "Vela; HERMES-TP/SP, CAMELOT (design)",
         "2.5$^\\circ$ (HP, pred.); 15$'$/coord. (goal)", "3--2000", True,
         "Could meet MIS-030 with enough spacecraft; carried to stage 2"),
        ("Count-rate ratios", "Fermi/GBM, BATSE, BurstCube",
         "3.71$^\\circ$ systematic core", "8--40\\,000", False,
         "Systematic floor $\\gg$ 10$'$: fails MIS-030"),
        ("Lobster-eye focusing", "Einstein Probe/WXT",
         "arcmin (soft X-ray)", "0.5--4", False,
         "Band outside PER-040 (5--50 keV): fails PER-040"),
    ]
    with open(os.path.join(OUT, "screening.tex"), "w", encoding="utf-8") as fh:
        fh.write("% generated by tradeoff_model.py - do not edit by hand\n")
        fh.write("\\begin{table}[htbp]\\centering\\small\n")
        fh.write("\\caption{Stage-1 screening of localization techniques against the threshold "
                 "requirements MIS-030 and PER-040. Values from \\cite{Barthelmy2005,Connaughton2015,"
                 "Fiore2020,Yuan2022}.}\\label{tab:screening}\n")
        fh.write("\\begin{tabularx}{\\linewidth}{@{}l l l l c X@{}}\\toprule\n")
        fh.write("Technique & Flown / designed on & Localization & Band [keV] & Go & Reason \\\\\\midrule\n")
        for t, fl, loc, band, go, why in rows:
            fh.write(f"{t} & {fl} & {loc} & {band} & {mark(go)}{'Go' if go else 'No-go'} & {why} \\\\\n")
        fh.write("\\bottomrule\\end{tabularx}\\end{table}\n")


def write_mask_design(alts, v):
    ms = [a for a in alts if a["name"].startswith("A")]
    rows = [
        ("Half-coded field of view $\\Omega$", "sr", lambda a: f(a["geo"]["omega"], 2)),
        ("FoV half-angle per axis $\\alpha$", "deg", lambda a: f(math.degrees(a["geo"]["alpha"]), 1)),
        ("Angular resolution $\\theta_{\\rm res}$ (FWHM)", "arcmin", lambda a: f(a["geo"]["theta"], 1)),
        ("Detector side $D$ (= mask side)", "cm", lambda a: f(a["geo"]["D"], 1)),
        ("Detector area $A$", "cm$^2$", lambda a: f(a["area"], 0)),
        ("Effective area $\\rho\\,\\varepsilon\\,A$", "cm$^2$", lambda a: f(a["a_eff"], 0)),
        ("Mask--detector distance $f$", "cm", lambda a: f(a["geo"]["f"], 1)),
        ("Pixel pitch $d$", "mm", lambda a: f(a["geo"]["d"] * 10, 2)),
        ("Pixels", "--", lambda a: f(a["geo"]["n_pix"], 0)),
        ("1-s flux limit at SNR 6.5", "$10^{-8}$\\,erg\\,cm$^{-2}$\\,s$^{-1}$", lambda a: f(a["F_lim"] * 1e8, 2)),
        ("Detector modules", "kg", lambda a: f(a["geo"]["m_det"], 1)),
        ("Mask and support", "kg", lambda a: f(a["geo"]["m_mask"], 1)),
        ("Shield", "kg", lambda a: f(a["geo"]["m_shield"], 1)),
        ("Data processing unit", "kg", lambda a: f(v["m_dpu"], 1)),
        ("Payload mass incl. 20\\,\\% margin", "kg", lambda a: f(a["m_pl"], 1)),
        ("Payload power", "W", lambda a: f(a["p_pl"], 1)),
    ]
    with open(os.path.join(OUT, "mask_design.tex"), "w", encoding="utf-8") as fh:
        fh.write("% generated by tradeoff_model.py - do not edit by hand\n")
        fh.write("\\begin{table}[htbp]\\centering\\small\n")
        fh.write("\\caption{First-principles coded-mask designs, Eqs.~\\eqref{eq:pflux}--\\eqref{eq:mass}. "
                 "A1 and A2 are sized to the PER-040 threshold and goal; A0 is the largest camera within "
                 "PHY-010.}\\label{tab:maskdesign}\n")
        fh.write("\\begin{tabular}{@{}l l " + "r" * len(ms) + "@{}}\\toprule\n")
        fh.write("Parameter & Unit & " + " & ".join(a["name"] for a in ms) + " \\\\\\midrule\n")
        for label, unit, fn in rows:
            fh.write(f"{label} & {unit} & " + " & ".join(fn(a) for a in ms) + " \\\\\n")
        fh.write("\\bottomrule\\end{tabular}\\end{table}\n")


def write_matrix(alts, v):
    crit = [
        ("Localization $r_{90}$ at SNR 8", "arcmin", "$\\le$10", "MIS-030", lambda a: f(a["r90"]),
         lambda a, c: c["MIS-030"]),
        ("GRBs detected", "yr$^{-1}$", "$\\ge$40", "MIS-020", lambda a: f(a["n_det"], 0),
         lambda a, c: c["MIS-020"]),
        ("$\\Omega\\,\\eta_{\\rm eff}$", "sr", "$\\ge$0.75", "PER-065",
         lambda a: f(a["fov_eta"], 2) if not math.isnan(a["fov_eta"]) else "fleet",
         lambda a, c: c["PER-065"]),
        ("Alerts within 30\\,s", "\\%", "$\\ge$66", "MIS-040", lambda a: f(a["lat_pct"], 1),
         lambda a, c: c["MIS-040"]),
        ("Usefully localized, $N_u$", "yr$^{-1}$", "$\\ge$30", "FoM", lambda a: f(a["n_u"], 1),
         lambda a, c: c["FoM"]),
        ("Payload mass (per s/c)", "kg", "$\\le$10\\,[TBC]", "PHY-010", lambda a: f(a["m_pl"], 1),
         lambda a, c: c["PHY-010"]),
        ("Payload power (per s/c)", "W", "$\\le$15\\,[TBC]", "PHY-020",
         lambda a: f(a["p_pl"], 1), lambda a, c: c["PHY-020"]),
        ("Spacecraft", "--", "--", "--", lambda a: f"{a['n_sc']}", None),
        ("Launch mass (total)", "kg", "--", "--", lambda a: f(a["m_launch"], 0), None),
        ("Cost, launch incl., ops excl.", "M\\$$_{2024}$", "--", "--", lambda a: f(a["cost"], 0), None),
        ("Cost per useful burst (2\\,yr)", "M\\$/GRB", "min", "Decision", lambda a: f(a["cpb"], 2), None),
        ("Localization evidence", "qual.", "--", "--", lambda a: a["evidence"], None),
    ]
    comp = {a["name"]: compliance(a, v) for a in alts}
    with open(os.path.join(OUT, "trade_matrix.tex"), "w", encoding="utf-8") as fh:
        fh.write("% generated by tradeoff_model.py - do not edit by hand\n")
        fh.write("\\begin{table*}[htbp]\\centering\\footnotesize\n")
        fh.write("\\caption{Stage-2 trade-off matrix for the localization architecture. Green: threshold met; "
                 "red: not met. PHY-010 and PHY-020 are open [TBC] values; they are reported but not used to "
                 "reject. The last row is the only qualitative criterion; it is used because the in-orbit "
                 "maturity of a localization chain cannot be expressed as a number. All values are computed "
                 "by \\texttt{tradeoff\\_model.py} (Appendix~\\ref{app:tradeoff}).}\\label{tab:tradematrix}\n")
        fh.write("\\begin{tabularx}{\\linewidth}{@{}l l l l " + "X" * len(alts) + "@{}}\\toprule\n")
        fh.write("Criterion & Unit & Thr. & Req. & " + " & ".join(NAMES[a["name"]] for a in alts) + " \\\\\\midrule\n")
        for label, unit, thr, req, val, chk in crit:
            cells = [(mark(chk(a, comp[a["name"]])) if chk else "") + val(a) for a in alts]
            fh.write(f"{label} & {unit} & {thr} & {req} & " + " & ".join(cells) + " \\\\\n")
        fh.write("\\midrule\nAll thresholds met & & & & " +
                 " & ".join(("\\textbf{yes}" if comp[a["name"]]["pass"] else "no") for a in alts) + " \\\\\n")
        fh.write("\\bottomrule\\end{tabularx}\\end{table*}\n")


def sensitivity(v0):
    cases = [
        ("Baseline", {}),
        ("$k_{\\rm loc}$ = 1.0", {"k_loc": 1.0}),
        ("$k_{\\rm loc}$ = 2.0", {"k_loc": 2.0}),
        ("Background 2 $\\times$ ENV-010", {"b_bkg": 2 * v0["b_bkg"]}),
        ("Detector efficiency 0.6", {"eps": 0.6}),
        ("$\\eta_{\\rm eff}$ = 0.50", {"eta_eff": 0.50}),
        ("Shield areal density 2 $\\times$", {"sig_shield": 2 * v0["sig_shield"]}),
        ("Detector module factor 4", {"k_fee": 4.0}),
        ("$\\beta$ = 0.8", {"beta": 0.8}),
        ("$\\beta$ = 1.5 (Euclidean)", {"beta": 1.5}),
        ("Dry/payload mass ratio = 2", {"dry_per_pl": 2.0}),
        ("Dry/payload mass ratio = 7", {"dry_per_pl": 7.0}),
        ("Payload cost = 0.8 $\\times$ bus", {"pl_cost_f": 0.8}),
        ("Triangulation $\\sigma_t$ = 0.2 ms", {"sig_t_opt": 0.2}),
        ("CubeSat TFU halved", {"hermes_sp": v0["hermes_sp"] / 2}),
        ("Launch price doubled", {"launch_kg": 2 * v0["launch_kg"]}),
    ]
    rows = []
    for label, ch in cases:
        v = dict(v0); v.update(ch)
        alts = alternatives(v)
        b_isl = triangulation("B1*", v["sig_t_opt"], v, latency_ok=True)
        get = {a["name"]: a for a in alts}
        rows.append((label, get["A1"], get["A2"], get["B1"], b_isl,
                     decide(alts, v), decide(alts + [b_isl], v)))
    return rows


def write_sensitivity(rows):
    with open(os.path.join(OUT, "sensitivity.tex"), "w", encoding="utf-8") as fh:
        fh.write("% generated by tradeoff_model.py - do not edit by hand\n")
        fh.write("\\begin{table*}[htbp]\\centering\\footnotesize\n")
        fh.write("\\caption{Sensitivity of the selection to every assumption and uncertain input "
                 "(one at a time). B1$^*$ is B1 with on-board inter-satellite triangulation assumed, "
                 "which no flown or funded mission has demonstrated. Cost per useful burst in M\\$/GRB "
                 "over 2 years.}\\label{tab:sensitivity}\n")
        fh.write("\\begin{tabularx}{\\linewidth}{@{}X r r r r r r c c@{}}\\toprule\n")
        fh.write("Case & A1 kg & A1 M\\$/GRB & A2 kg & A2 M\\$/GRB & B1 s/c & B1$^*$ M\\$/GRB & "
                 "Selected & Selected if ISL \\\\\\midrule\n")
        for label, a1, a2, b1, bi, sel, seli in rows:
            fh.write(f"{label} & {f(a1['m_pl'])} & {f(a1['cpb'],2)} & {f(a2['m_pl'])} & {f(a2['cpb'],2)} & "
                     f"{b1['n_sc']} & {f(bi['cpb'],2)} & {sel} & {seli} \\\\\n")
        fh.write("\\bottomrule\\end{tabularx}\\end{table*}\n")


def write_inputs():
    def esc(s):
        return (s.replace("\\", "/").replace("_", "\\_").replace("%", "\\%").replace("&", "\\&")
                 .replace("$", "\\$").replace("~", "$\\sim$").replace("^", "\\^{}").replace("#", "\\#")
                 .replace(">=", "$\\ge$").replace("<=", "$\\le$").replace(">", "$>$").replace("<", "$<$"))
    with open(os.path.join(OUT, "inputs.tex"), "w", encoding="utf-8") as fh:
        fh.write("% generated by tradeoff_model.py - do not edit by hand\n")
        fh.write("\\begin{longtable}{@{}l r l p{0.55\\linewidth}@{}}\n")
        fh.write("\\caption{Inputs of the architecture trade-off model and their sources. "
                 "ASSUMPTION = team assumption, varied in Table~\\ref{tab:sensitivity}; "
                 "DERIVED = computed from the cited values.}\\label{tab:tradeinputs}\\\\\\toprule\n")
        fh.write("Symbol & Value & Unit & Source \\\\\\midrule\\endfirsthead\n")
        fh.write("\\toprule Symbol & Value & Unit & Source \\\\\\midrule\\endhead\n")
        for k, (val, unit, src) in P.items():
            fh.write(f"\\texttt{{{esc(k)}}} & {val:g} & {esc(unit)} & {esc(src)} \\\\\n")
        fh.write("\\bottomrule\\end{longtable}\n")


def main():
    alts = alternatives(V)
    write_inputs()
    write_screening()
    write_mask_design(alts, V)
    write_matrix(alts, V)
    rows = sensitivity(V)
    write_sensitivity(rows)

    keys = ["name", "kind", "n_sc", "area", "a_eff", "F_lim", "m_pl", "p_pl", "m_launch", "fov_eta",
            "r90", "n_det", "lat_pct", "n_u", "cost", "cpb", "model_ok", "evidence"]
    with open(os.path.join(OUT, "results.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh); w.writerow(keys)
        for a in alts:
            w.writerow([a.get(k) for k in keys])
        w.writerow([]); w.writerow(["input", "value", "unit", "source"])
        for k, (val, unit, src) in P.items():
            w.writerow([k, val, unit, src])

    print(f"PER-040 threshold as photon flux: {photon_flux(V['F_req'], V):.3f} ph/cm2/s")
    print("=== Stage-2 alternatives ===")
    for a in alts:
        c = compliance(a, V)
        print(f"{a['name']:3s} {a['kind']:34s} A={f(a['area'],0):>8s} r90={a['r90']:6.1f}' Ndet={a['n_det']:6.1f} "
              f"lat30={a['lat_pct']:5.1f}% Nu={a['n_u']:6.1f} m_pl={a['m_pl']:5.1f}kg p_pl={a['p_pl']:5.1f}W "
              f"m={a['m_launch']:6.0f}kg cost={a['cost']:6.1f}M$ cpb={a['cpb']:5.2f} SSCM={a['model_ok']} "
              f"pass={c['pass']} fails={[k for k in c if k != 'pass' and not c[k]]}")
        if "geo" in a:
            g = a["geo"]
            print(f"     D={g['D']:.1f}cm f={g['f']:.1f}cm d={g['d']*10:.2f}mm theta={g['theta']:.1f}' "
                  f"Omega={g['omega']:.2f}sr alpha={math.degrees(g['alpha']):.1f}deg npix={g['n_pix']:.0f} "
                  f"det={g['m_det']:.1f} mask={g['m_mask']:.1f} shield={g['m_shield']:.1f} kg")
    print("Selected:", decide(alts, V))
    b_cxb, i_cxb = cxb_background(V, alts[0]["geo"])
    print(f"CXB check: {i_cxb:.2f} ph/(cm2 s sr) in band -> {b_cxb:.2f} cts/cm2/s through mask "
          f"(ENV-010 allows {V['b_bkg']:.1f})")
    print("\n=== Sensitivity ===")
    for label, a1, a2, b1, bi, sel, seli in rows:
        print(f"{label:38s} A1 {a1['m_pl']:5.1f}kg {a1['cpb']:5.2f} pass={compliance(a1, V)['pass']}  "
              f"A2 {a2['m_pl']:5.1f}kg {a2['cpb']:5.2f}  B1 n={b1['n_sc']:5d}  B1* {bi['cpb']:5.2f}  "
              f"sel={sel} selISL={seli}")


if __name__ == "__main__":
    main()
