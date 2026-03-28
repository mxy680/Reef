#!/usr/bin/env python3
"""Run 5 complex problems across subjects through the full stroke pipeline.

Simulates a struggling student on each: makes mistakes, fixes them,
tests the tutor's ability to guide through advanced material.

Usage:
    python scripts/scenarios/stress_5subjects.py
"""

import json
import os
import sys

import httpx

_here = os.path.dirname(os.path.abspath(__file__))
_scripts_dir = os.path.dirname(_here)
_server_root = os.path.dirname(_scripts_dir)
if _server_root not in sys.path:
    sys.path.insert(0, _server_root)

# ---------------------------------------------------------------------------
# Env + auth
# ---------------------------------------------------------------------------

def get_token():
    env = {}
    for line in open(os.path.expanduser("~/.config/reef/server.env")):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()
    resp = httpx.post(
        f"{env['SUPABASE_URL']}/auth/v1/token?grant_type=password",
        headers={"apikey": env["SUPABASE_ANON_KEY"], "Content-Type": "application/json"},
        json={"email": "sim@studyreef.com", "password": "SimTest123!"},
        timeout=10,
    )
    data = resp.json()
    return data["access_token"], data["user"]["id"], env

SERVER = "https://api.studyreef.com"

# ---------------------------------------------------------------------------
# Helpers (copied from simulate_tutor.py to keep standalone)
# ---------------------------------------------------------------------------

def supabase_headers(env):
    key = env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    return {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}

def setup_doc(env, user_id, scenario):
    import uuid
    doc_id = str(uuid.uuid4())
    url = env["SUPABASE_URL"]
    h = supabase_headers(env)
    httpx.post(f"{url}/rest/v1/documents", json={
        "id": doc_id, "user_id": user_id, "filename": "stress-test.pdf",
        "status": "completed", "page_count": 1, "problem_count": 1,
        "question_pages": [[0, 0]],
    }, headers=h, timeout=5)

    ak = {
        "question_number": scenario["question_number"],
        "steps": [], "final_answer": scenario.get("final_answer", ""),
        "parts": [{"label": scenario["part_label"], "steps": scenario["steps"],
                    "final_answer": scenario.get("final_answer", ""), "parts": []}],
    }
    httpx.post(f"{url}/rest/v1/answer_keys", json={
        "document_id": doc_id, "question_number": scenario["question_number"],
        "answer_text": json.dumps(ak),
        "question_json": {"number": scenario["question_number"],
                         "text": scenario["question_text"],
                         "parts": [{"label": scenario["part_label"], "text": "", "parts": []}]},
        "model": "stress-test", "input_tokens": 0, "output_tokens": 0,
    }, headers=h, timeout=5)
    return doc_id

def upsert_work(env, doc_id, q_label, user_id, latex):
    h = supabase_headers(env)
    h["Prefer"] = "resolution=merge-duplicates"
    httpx.post(f"{env['SUPABASE_URL']}/rest/v1/student_work", json={
        "user_id": user_id, "document_id": doc_id,
        "question_label": q_label, "latex_display": latex, "latex_raw": latex,
    }, headers=h, timeout=5)

def cleanup_doc(env, doc_id):
    h = supabase_headers(env)
    url = env["SUPABASE_URL"]
    for t in ["student_work", "chat_history", "answer_keys"]:
        httpx.delete(f"{url}/rest/v1/{t}?document_id=eq.{doc_id}", headers=h, timeout=5)
    httpx.delete(f"{url}/rest/v1/documents?id=eq.{doc_id}", headers=h, timeout=5)

def get_session(token):
    resp = httpx.post(f"{SERVER}/ai/strokes-session",
                      headers={"Authorization": f"Bearer {token}"}, timeout=10)
    resp.raise_for_status()
    d = resp.json()
    return d["app_token"], d["strokes_session_id"]

def stroke_transcribe(latex_input, token, app_tok, sess_id):
    from app.services.latex2strokes import latex_to_strokes
    strokes = latex_to_strokes(latex_input, jitter=False)
    resp = httpx.post(f"{SERVER}/ai/transcribe-strokes",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"strokes": strokes, "app_token": app_tok, "session_id": sess_id}, timeout=20)
    if resp.status_code != 200:
        return f"[ERROR {resp.status_code}]"
    return resp.json().get("latex", "")

def call_eval(token, doc_id, q_num, part, step_idx):
    resp = httpx.post(f"{SERVER}/ai/tutor-evaluate",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"document_id": doc_id, "question_number": q_num, "part_label": part,
              "step_index": step_idx, "student_latex": "", "figure_urls": []}, timeout=60)
    if resp.status_code != 200:
        return {"status": f"ERROR:{resp.status_code}", "progress": 0}
    return resp.json()

# ---------------------------------------------------------------------------
# 5 scenarios
# ---------------------------------------------------------------------------

SCENARIOS = [
    # 1. MATH: Triple integral in cylindrical coordinates
    {
        "subject": "MATH",
        "question_text": r"Evaluate $\iiint_E z \, dV$ where E is the solid bounded by $z = 4 - x^2 - y^2$ and $z = 0$. Use cylindrical coordinates.",
        "question_number": 1, "part_label": "a",
        "final_answer": r"\\frac{16\\pi}{3}",
        "steps": [
            {"description": "Convert to cylindrical coordinates: x=rcosθ, y=rsinθ, z=z, dV=r dz dr dθ",
             "explanation": "What replaces x²+y² in cylindrical?",
             "work": "z = 4 - r^2, \\quad dV = r \\, dz \\, dr \\, d\\theta",
             "reinforcement": "Clean conversion — r² replaces x²+y².",
             "tutor_speech": "Convert to cylindrical coordinates.", "concepts": ["cylindrical_coordinates"]},
            {"description": "Set up the bounds: θ from 0 to 2π, r from 0 to 2, z from 0 to 4-r²",
             "explanation": "Where does the paraboloid hit z=0?",
             "work": "\\int_0^{2\\pi} \\int_0^2 \\int_0^{4-r^2} z \\cdot r \\, dz \\, dr \\, d\\theta",
             "reinforcement": "Bounds are correct — r goes to 2 where 4-r²=0.",
             "tutor_speech": "Set up the integration bounds.", "concepts": ["integration_bounds"]},
            {"description": "Evaluate the inner integral (dz)",
             "explanation": "What's the integral of z dz from 0 to 4-r²?",
             "work": "\\int_0^{4-r^2} z \\, dz = \\frac{(4-r^2)^2}{2}",
             "reinforcement": "Inner integral done — z²/2 evaluated at the bounds.",
             "tutor_speech": "Evaluate the inner integral.", "concepts": ["integration"]},
            {"description": "Evaluate the middle integral (dr) with the substitution",
             "explanation": "Expand (4-r²)² and integrate term by term.",
             "work": "\\int_0^2 \\frac{(4-r^2)^2}{2} r \\, dr = \\int_0^2 \\frac{r(16 - 8r^2 + r^4)}{2} dr = \\frac{8}{3}",
             "reinforcement": "Middle integral evaluated — careful polynomial expansion.",
             "tutor_speech": "Evaluate the dr integral.", "concepts": ["polynomial_integration"]},
            {"description": "Evaluate the outer integral (dθ) and state the final answer",
             "explanation": "The θ integral of a constant over [0, 2π] is just 2π times that constant.",
             "work": "\\int_0^{2\\pi} \\frac{8}{3} d\\theta = \\frac{16\\pi}{3}",
             "reinforcement": "Final answer 16π/3 — multi-variable integration complete.",
             "tutor_speech": "Evaluate the outer integral for the final answer.", "concepts": ["integration"]},
        ],
        "inputs": [
            ("z = 4 - r^2, dV = r dz dr d\\theta", True),
            ("\\int_0^{2\\pi} \\int_0^2 \\int_0^{4-r^2} z r dz dr d\\theta", True),
            ("\\int_0^{4-r^2} z dz = (4-r^2)^2", False),  # missing /2
            ("\\int_0^{4-r^2} z dz = \\frac{(4-r^2)^2}{2}", True),
            ("\\int_0^2 \\frac{r(16 - 8r^2 + r^4)}{2} dr = \\frac{8}{3}", True),
            ("\\frac{16\\pi}{3}", True),
        ],
    },

    # 2. PHYSICS: Coupled oscillator / Lagrangian mechanics
    {
        "subject": "PHYSICS",
        "question_text": r"A mass $m$ slides on a frictionless inclined plane of angle $\theta = 30°$ and mass $M = 4m$, which itself slides on a frictionless horizontal surface. Find the acceleration of $m$ relative to the ground.",
        "question_number": 1, "part_label": "a",
        "final_answer": "a = g sin(30) (M + m sin^2(30)) / (M + m)",
        "steps": [
            {"description": "Draw free body diagrams and identify the forces on m and M",
             "explanation": "What forces act on the mass on the incline? On the wedge?",
             "work": "m: mg \\text{ (down)}, N \\text{ (normal to incline)}; \\quad M: Mg, N', N \\text{ (reaction)}",
             "reinforcement": "Good — both FBDs identified correctly.",
             "tutor_speech": "Draw free body diagrams for both masses.", "concepts": ["free_body_diagram"]},
            {"description": "Write Newton's second law for M (horizontal direction)",
             "explanation": "The wedge accelerates horizontally. What horizontal force does the small mass exert on it?",
             "work": "N \\sin\\theta = (M + m) a_M",
             "reinforcement": "Correct — normal force component drives the wedge horizontally.",
             "tutor_speech": "Write Newton's second law for the wedge.", "concepts": ["newtons_second_law"]},
            {"description": "Write Newton's second law for m along and perpendicular to the incline",
             "explanation": "In the non-inertial frame of the wedge, what pseudo-force appears?",
             "work": "mg\\sin\\theta - ma_M\\cos\\theta = ma_{rel}",
             "reinforcement": "Pseudo-force included correctly in the accelerating frame.",
             "tutor_speech": "Write equations of motion for m on the incline.", "concepts": ["non_inertial_frames"]},
            {"description": "Solve the system of equations for a_M and a_rel",
             "explanation": "Eliminate N between the equations to find a_M.",
             "work": "a_M = \\frac{mg\\sin\\theta\\cos\\theta}{M + m\\sin^2\\theta}",
             "reinforcement": "System solved — wedge acceleration found.",
             "tutor_speech": "Solve for the accelerations.", "concepts": ["system_of_equations"]},
            {"description": "Find the acceleration of m relative to the ground",
             "explanation": "Combine a_rel (along incline) with a_M (horizontal) vectorially.",
             "work": "a_m = \\sqrt{a_{rel}^2 + a_M^2 + 2a_{rel}a_M\\cos\\theta}",
             "reinforcement": "Complete — acceleration of m relative to ground found via vector addition.",
             "tutor_speech": "Find the total acceleration of m.", "concepts": ["vector_addition"]},
        ],
        "inputs": [
            ("mg, N, Mg, N'", True),
            ("N sin(30) = (M + m) a_M", True),
            ("mg sin(30) + ma_M cos(30) = ma_{rel}", False),  # wrong sign on pseudo-force
            ("mg sin(30) - ma_M cos(30) = ma_{rel}", True),
            ("a_M = \\frac{mg sin(30) cos(30)}{M + m sin^2(30)}", True),
            ("a_m = \\sqrt{a_{rel}^2 + a_M^2 + 2 a_{rel} a_M cos(30)}", True),
        ],
    },

    # 3. CHEMISTRY: Multi-step organic mechanism
    {
        "subject": "CHEMISTRY",
        "question_text": r"For the reaction of 2-bromobutane with NaOH in ethanol, predict the major product and draw the full E2 elimination mechanism. Calculate the ratio of Zaitsev to Hofmann products.",
        "question_number": 1, "part_label": "a",
        "final_answer": "trans-2-butene (Zaitsev product, ~80%)",
        "steps": [
            {"description": "Identify the reaction type: E2 elimination with strong base in polar protic solvent",
             "explanation": "NaOH is a strong base. What mechanism does a strong base favor?",
             "work": "\\text{E2: strong base (OH-), secondary substrate, heated ethanol}",
             "reinforcement": "Correct — E2 is favored over SN2 with strong base + secondary carbon.",
             "tutor_speech": "Identify the reaction type.", "concepts": ["elimination_reactions"]},
            {"description": "Identify all possible beta-hydrogens and the two possible products",
             "explanation": "Which carbons adjacent to the C-Br have hydrogens that can be removed?",
             "work": "\\beta_1: CH_3 \\text{ (C1, 3H, Hofmann)}, \\quad \\beta_2: CH_2 \\text{ (C3, 2H, Zaitsev)}",
             "reinforcement": "Both beta positions identified — C1 gives less substituted, C3 gives more substituted alkene.",
             "tutor_speech": "Identify the beta hydrogens.", "concepts": ["beta_elimination"]},
            {"description": "Apply Zaitsev's rule to predict the major product",
             "explanation": "Which alkene is more substituted?",
             "work": "\\text{Major: trans-2-butene (more substituted, Zaitsev)}",
             "reinforcement": "Zaitsev's rule: more substituted alkene is the major product.",
             "tutor_speech": "Predict the major product.", "concepts": ["zaitsevs_rule"]},
            {"description": "Draw the anti-periplanar transition state for E2",
             "explanation": "In E2, the H and leaving group must be anti-periplanar (180°). Draw the Newman projection.",
             "work": "\\text{Anti arrangement: H and Br at 180° dihedral in Newman projection}",
             "reinforcement": "Anti-periplanar geometry is key to E2 — determines which stereoisomer forms.",
             "tutor_speech": "Draw the anti-periplanar transition state.", "concepts": ["stereochemistry"]},
            {"description": "Explain why trans-2-butene is favored over cis-2-butene",
             "explanation": "In the anti-periplanar TS, where do the methyl groups end up?",
             "work": "\\text{Anti TS places CH}_3\\text{ groups on opposite sides} \\implies \\text{trans product}",
             "reinforcement": "Trans is thermodynamically more stable AND kinetically favored from the anti TS.",
             "tutor_speech": "Explain the trans selectivity.", "concepts": ["stereoselectivity"]},
        ],
        "inputs": [
            ("E2, strong base OH-, secondary substrate", True),
            ("C1: 3H (Hofmann), C3: 2H (Zaitsev)", True),
            ("Major: 1-butene", False),  # Wrong — that's Hofmann product
            ("Major: trans-2-butene (Zaitsev)", True),
            ("H and Br at 180 degrees, anti-periplanar", True),
            ("anti TS: CH3 groups opposite sides, trans product", True),
        ],
    },

    # 4. BIOLOGY: Hardy-Weinberg with selection
    {
        "subject": "BIOLOGY",
        "question_text": r"In a population of 10,000 organisms, a recessive allele $q$ causes a disease with frequency 1/2500. If heterozygote carriers have a 5% fitness advantage (heterozygote advantage), calculate the equilibrium allele frequencies and the expected number of carriers in the next generation.",
        "question_number": 1, "part_label": "a",
        "final_answer": "q_eq ≈ 0.02, carriers ≈ 392",
        "steps": [
            {"description": "Find the current allele frequencies from the disease frequency",
             "explanation": "If q² = disease frequency, what is q?",
             "work": "q^2 = \\frac{1}{2500} \\implies q = \\frac{1}{50} = 0.02, \\quad p = 0.98",
             "reinforcement": "Good — q = 0.02 from the square root of the disease frequency.",
             "tutor_speech": "Find p and q from the disease frequency.", "concepts": ["hardy_weinberg"]},
            {"description": "Write the fitness values for each genotype",
             "explanation": "AA has fitness 1, Aa has fitness 1.05, aa has fitness... what?",
             "work": "w_{AA} = 1, \\quad w_{Aa} = 1.05, \\quad w_{aa} = 1 - s",
             "reinforcement": "Fitness values set up — heterozygote has the advantage.",
             "tutor_speech": "Assign fitness values to each genotype.", "concepts": ["natural_selection"]},
            {"description": "Calculate the mean fitness of the population",
             "explanation": "Mean fitness = sum of (genotype frequency × fitness) for all genotypes.",
             "work": "\\bar{w} = p^2(1) + 2pq(1.05) + q^2(1-s) \\approx 1 + 2pq(0.05) - q^2 s",
             "reinforcement": "Mean fitness calculated — the heterozygote term increases it above 1.",
             "tutor_speech": "Calculate mean population fitness.", "concepts": ["population_genetics"]},
            {"description": "Find the equilibrium condition where delta-q = 0",
             "explanation": "At equilibrium, the allele frequency doesn't change. Set dq/dt = 0.",
             "work": "\\hat{q} = \\frac{h \\cdot s_{het}}{s_{aa} + h \\cdot s_{het}} \\approx 0.02",
             "reinforcement": "Equilibrium frequency calculated — balancing selection maintains the allele.",
             "tutor_speech": "Find the equilibrium allele frequency.", "concepts": ["balancing_selection"]},
            {"description": "Calculate the expected number of carriers (2pq × N)",
             "explanation": "Carriers are heterozygotes. What's their frequency?",
             "work": "2pq = 2(0.98)(0.02) = 0.0392, \\quad \\text{carriers} = 0.0392 \\times 10000 = 392",
             "reinforcement": "392 carriers in a population of 10,000 — nearly 4% are carriers.",
             "tutor_speech": "Calculate the number of carriers.", "concepts": ["genotype_frequencies"]},
        ],
        "inputs": [
            ("q^2 = 1/2500, q = 1/50 = 0.02, p = 0.98", True),
            ("w_{AA} = 1, w_{Aa} = 1.05, w_{aa} = 1 - s", True),
            ("\\bar{w} = p^2 + 2pq(1.05) + q^2(1-s)", True),
            ("q_{eq} = 0.02", True),
            ("2pq = 2(0.98)(0.02) = 0.0392, carriers = 392", True),
        ],
    },

    # 5. ECONOMICS: IS-LM model with fiscal + monetary policy
    {
        "subject": "ECONOMICS",
        "question_text": r"In an IS-LM model, $C = 200 + 0.75(Y-T)$, $I = 200 - 25r$, $G = 100$, $T = 100$, $M/P = 1000$, $L(Y,r) = Y - 100r$. Find equilibrium Y and r. Then calculate the effect of increasing G by 50 (fiscal expansion) with and without monetary accommodation.",
        "question_number": 1, "part_label": "a",
        "final_answer": "Y=1100, r=1; after fiscal: Y=1150, r=1.5 (no accommodation); Y=1200, r=1 (with accommodation)",
        "steps": [
            {"description": "Derive the IS curve: set goods market equilibrium Y = C + I + G",
             "explanation": "Substitute C, I, G into Y = C + I + G and solve for Y in terms of r.",
             "work": "Y = 200 + 0.75(Y - 100) + 200 - 25r + 100 \\implies Y = 1800 - 100r",
             "reinforcement": "IS curve derived: Y = 1800 - 100r. Downward sloping as expected.",
             "tutor_speech": "Derive the IS curve.", "concepts": ["is_curve"]},
            {"description": "Derive the LM curve: set money market equilibrium M/P = L(Y,r)",
             "explanation": "Set money supply equal to money demand and solve for Y in terms of r.",
             "work": "1000 = Y - 100r \\implies Y = 1000 + 100r",
             "reinforcement": "LM curve: Y = 1000 + 100r. Upward sloping — higher income needs higher r.",
             "tutor_speech": "Derive the LM curve.", "concepts": ["lm_curve"]},
            {"description": "Find equilibrium by solving IS = LM simultaneously",
             "explanation": "Set the IS and LM equations equal and solve for r, then Y.",
             "work": "1800 - 100r = 1000 + 100r \\implies 200r = 800 \\implies r = 4, Y = 1400",
             "reinforcement": "Equilibrium at Y=1400, r=4.",
             "tutor_speech": "Solve for equilibrium Y and r.", "concepts": ["equilibrium"]},
            {"description": "Calculate the fiscal multiplier and new equilibrium with G increased by 50",
             "explanation": "How does the IS curve shift when G increases? What's the multiplier with crowding out?",
             "work": "\\text{New IS: } Y = 2000 - 100r; \\quad 2000 - 100r = 1000 + 100r \\implies r = 5, Y = 1500",
             "reinforcement": "Fiscal expansion: Y rises by 100 (not 200 due to crowding out) and r rises to 5.",
             "tutor_speech": "Find the new equilibrium after fiscal expansion.", "concepts": ["fiscal_policy", "crowding_out"]},
            {"description": "Calculate equilibrium with monetary accommodation (M/P increases to keep r constant)",
             "explanation": "If the central bank increases M/P to keep r=4, what Y results?",
             "work": "\\text{Keep } r = 4: Y = 2000 - 100(4) = 1600; \\quad M/P = 1600 - 100(4) = 1200",
             "reinforcement": "With accommodation: full multiplier effect, Y=1600, no crowding out.",
             "tutor_speech": "Calculate the effect with monetary accommodation.", "concepts": ["monetary_policy"]},
        ],
        "inputs": [
            ("Y = 200 + 0.75(Y - 100) + 200 - 25r + 100", True),
            ("1000 = Y - 100r, Y = 1000 + 100r", True),
            ("1800 - 100r = 1000 + 100r, r = 4, Y = 1400", True),
            ("New IS: Y = 2000 - 100r, r = 5, Y = 1500", True),
            ("r = 4, Y = 1600, M/P = 1200", True),
        ],
    },
]

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

def run_one(scenario, token, user_id, env, app_tok, sess_id):
    subject = scenario["subject"]
    print(f"\n{'='*70}")
    print(f"  {subject}: {scenario['question_text'][:80]}...")
    print(f"{'='*70}")

    doc_id = setup_doc(env, user_id, scenario)
    q_num = scenario["question_number"]
    part = scenario["part_label"]
    q_label = f"Q{q_num}{part}"
    steps = scenario["steps"]
    inputs = scenario["inputs"]

    accumulated = []
    step_idx = 0
    mistakes = 0
    completions = 0
    socratic_quality = []

    for latex_input, should_pass in inputs:
        if step_idx >= len(steps):
            break

        # Convert to strokes
        transcribed = stroke_transcribe(latex_input, token, app_tok, sess_id)
        accumulated.append(transcribed)
        latex_so_far = "\n".join(accumulated)
        upsert_work(env, doc_id, q_label, user_id, latex_so_far)

        # Eval
        resp = call_eval(token, doc_id, q_num, part, step_idx)
        status = resp.get("status", "?")
        progress = resp.get("progress", 0)
        mistake = resp.get("mistake_explanation", "")
        steps_completed = resp.get("steps_completed", 1)

        step_desc = steps[step_idx]["description"][:50]
        print(f"\n  Step {step_idx+1}/{len(steps)}: {step_desc}...")
        print(f"  Wrote:   {latex_input[:60]}")
        print(f"  Mathpix: {transcribed[:60]}")
        print(f"  Status:  {status}  Progress: {progress:.0%}")

        if status == "mistake":
            mistakes += 1
            print(f"  Tutor:   {mistake[:80]}")
            if not should_pass:
                socratic_quality.append("correct_catch")
                print(f"  [Expected mistake — tutor caught it ✓]")
            else:
                socratic_quality.append("false_positive")
                print(f"  [UNEXPECTED — should have passed ✗]")
        elif status == "completed":
            completions += 1
            reinforcement = steps[step_idx].get("reinforcement", "")
            print(f"  Tutor:   {reinforcement[:80]}")
            step_idx += steps_completed
            if should_pass:
                socratic_quality.append("correct_pass")
                print(f"  [Expected completion ✓]")
            else:
                socratic_quality.append("false_negative")
                print(f"  [UNEXPECTED — should have caught mistake ✗]")
        else:
            print(f"  [Status: {status}]")

    cleanup_doc(env, doc_id)

    correct_catches = socratic_quality.count("correct_catch")
    correct_passes = socratic_quality.count("correct_pass")
    false_pos = socratic_quality.count("false_positive")
    false_neg = socratic_quality.count("false_negative")
    total = len(socratic_quality)

    print(f"\n  {'─'*50}")
    print(f"  {subject} RESULTS:")
    print(f"  Steps completed: {completions}/{len(steps)}")
    print(f"  Mistakes caught: {correct_catches}")
    print(f"  False positives: {false_pos}")
    print(f"  False negatives: {false_neg}")
    print(f"  Accuracy: {(correct_catches + correct_passes)}/{total} = {(correct_catches + correct_passes)*100//max(total,1)}%")

    return {
        "subject": subject,
        "steps": len(steps),
        "completions": completions,
        "correct_catches": correct_catches,
        "correct_passes": correct_passes,
        "false_pos": false_pos,
        "false_neg": false_neg,
        "total": total,
    }


def main():
    print("\n  ╔══════════════════════════════════════════════════╗")
    print("  ║  REEF TUTOR: 5-Subject Stress Test (Full Pipe)  ║")
    print("  ╚══════════════════════════════════════════════════╝")

    token, user_id, env = get_token()
    app_tok, sess_id = get_session(token)
    print(f"  Server: {SERVER}")
    print(f"  Stroke mode: ON (session {sess_id[:12]}...)")

    results = []
    for scenario in SCENARIOS:
        r = run_one(scenario, token, user_id, env, app_tok, sess_id)
        results.append(r)

    # Summary
    print(f"\n\n  {'='*60}")
    print(f"  SUMMARY")
    print(f"  {'='*60}")
    print(f"  {'Subject':<12} {'Steps':>6} {'Done':>6} {'Caught':>8} {'FP':>4} {'FN':>4} {'Acc':>6}")
    print(f"  {'─'*60}")
    total_correct = 0
    total_all = 0
    for r in results:
        acc = (r["correct_catches"] + r["correct_passes"]) * 100 // max(r["total"], 1)
        total_correct += r["correct_catches"] + r["correct_passes"]
        total_all += r["total"]
        print(f"  {r['subject']:<12} {r['steps']:>6} {r['completions']:>6} {r['correct_catches']:>8} {r['false_pos']:>4} {r['false_neg']:>4} {acc:>5}%")
    print(f"  {'─'*60}")
    print(f"  {'OVERALL':<12} {'':>6} {'':>6} {'':>8} {'':>4} {'':>4} {total_correct*100//max(total_all,1):>5}%")
    print()


if __name__ == "__main__":
    main()
