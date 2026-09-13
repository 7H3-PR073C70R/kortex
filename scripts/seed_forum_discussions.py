#!/usr/bin/env python3
"""
Kortex Forum Seeding Script
===========================
Populates the database with realistic, highly engaging academic forum posts,
complete with:
- Posts without images, posts with 1 image, and posts with multiple images.
- Dynamic, non-fixed reply lengths with realistic student personas and voices.
- Deep nested sub-replies (conversational threads and clarifications).
- Automated Syllabot AI pedagogical responses with LaTeX formulas.
- Verified solution badges and accurate reply counter rollups.
- Configurable counts via command-line arguments or interactive prompts.
"""

import sys
import os
import json
import uuid
import random
import argparse
import datetime
from urllib import request, error

# Default Configuration
DEFAULT_API_URL = "https://mongizqfijuhycdxltpw.supabase.co"
DEFAULT_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpenFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMjk0ODksImV4cCI6MjEwMzcwNTQ4OX0.WdbPP0hWHnm2P7IWOOPOPv8emJsNql2jf5z6XnPa0wg"

# Realistic Student & Professor Personas
PERSONAS = [
    {
        "name": "Dr. Adebayo Ogunleye",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80",
        "role": "Academic Mentor",
        "track": "Engineering",
    },
    {
        "name": "Elena Rostova",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&auto=format&fit=crop&q=80",
        "role": "Physics Scholar",
        "track": "Physics",
    },
    {
        "name": "Marcus Chen",
        "avatar": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150&auto=format&fit=crop&q=80",
        "role": "Applied Math Major",
        "track": "Mathematics",
    },
    {
        "name": "Amara Diallo",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&auto=format&fit=crop&q=80",
        "role": "Pre-Med Scholar",
        "track": "Medicine",
    },
    {
        "name": "Liam O'Connor",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80",
        "role": "CS Student",
        "track": "Computer Science",
    },
    {
        "name": "Fatima Al-Mansoor",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&auto=format&fit=crop&q=80",
        "role": "Biochemistry Researcher",
        "track": "Chemistry",
    },
    {
        "name": "Chinedu Eze",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80",
        "role": "JAMB / WAEC Top Achiever",
        "track": "JAMB",
    },
    {
        "name": "Sophia Vance",
        "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80",
        "role": "SAT Math 800 Scholar",
        "track": "SAT",
    },
    {
        "name": "David Kweku",
        "avatar": "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150&auto=format&fit=crop&q=80",
        "role": "Robotics Peer",
        "track": "Engineering",
    },
    {
        "name": "Zainab Haruna",
        "avatar": "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&auto=format&fit=crop&q=80",
        "role": "Data Structures TA",
        "track": "Computer Science",
    },
]

SYLLABOT_PERSONA = {
    "name": "Syllabot AI",
    "avatar": "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=150&auto=format&fit=crop&q=80",
    "role": "Adaptive AI Tutor",
}

# Real-world Educational & Scientific Images for Posts
ACADEMIC_IMAGES = {
    "circuit": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80",
    "calculus_board": "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800&auto=format&fit=crop&q=80",
    "lab_chemistry": "https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=800&auto=format&fit=crop&q=80",
    "brain_synapse": "https://images.unsplash.com/photo-1559757175-5700dde675bc?w=800&auto=format&fit=crop&q=80",
    "study_notes": "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&auto=format&fit=crop&q=80",
    "code_editor": "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80",
    "physics_mechanics": "https://images.unsplash.com/photo-1509228468518-180dd4864904?w=800&auto=format&fit=crop&q=80",
    "library_study": "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=800&auto=format&fit=crop&q=80",
    "microscope_biology": "https://images.unsplash.com/photo-1579154204601-01588f351e67?w=800&auto=format&fit=crop&q=80",
}

# Post Templates covering varied domains, image configurations, and LaTeX formulations
POST_TEMPLATES = [
    {
        "title": "Stuck on evaluating this tricky contour integral using Cauchy's Residue Theorem",
        "track": "Mathematics",
        "syllabus_tag": "Complex Analysis",
        "content": "I am working through past exam problems for Complex Variables. The problem asks to evaluate the integral around the counterclockwise unit circle $|z| = 2$:\n\nCan someone walk me through how to classify the pole orders and find the residues without getting lost in algebraic expansion?",
        "latex_content": "\\oint_{|z|=2} \\frac{e^{3z}}{(z^2 + 1)(z - 1)^2} \\, dz",
        "tags": ["Calculus", "ComplexAnalysis", "ResidueTheorem", "PastQuestions"],
        "media_type": "multiple",
        "media_keys": ["calculus_board", "study_notes"],
        "is_question": True,
        "replies": [
            {
                "author_idx": 2,
                "content": "Look at the singularities inside $|z| = 2$. You have simple poles at $z = i$ and $z = -i$, and a double pole at $z = 1$. Since all three lie inside the circle of radius 2, you need the sum of all three residues!",
                "latex": "\\text{Res}(f, 1) = \\lim_{z \\to 1} \\frac{d}{dz} \\left[ (z-1)^2 f(z) \\right] = \\lim_{z \\to 1} \\frac{d}{dz} \\left[ \\frac{e^{3z}}{z^2 + 1} \\right]",
                "sub_replies": [
                    {
                        "author_idx": 1,
                        "content": "Wait Marcus, for the derivative at $z=1$, don't forget the quotient rule:\n$$\\frac{3e^{3z}(z^2+1) - 2z e^{3z}}{(z^2+1)^2}$$\nPlugging in $z=1$ gives $\\frac{6e^3 - 2e^3}{4} = e^3$.",
                    },
                    {
                        "author_idx": 2,
                        "content": "Spot on Elena! That quotient rule simplifies the double pole cleanly.",
                    },
                ],
            },
            {
                "is_ai": True,
                "content": "### Syllabot Step-by-Step Residue Evaluation\n\n1. **Identify Singularities within $|z| = 2$**:\n   - Simple pole at $z = i$: $\\text{Res}(f, i) = \\frac{e^{3i}}{2i(i-1)^2} = \\frac{e^{3i}}{4}$\n   - Simple pole at $z = -i$: $\\text{Res}(f, -i) = \\frac{e^{-3i}}{-2i(-i-1)^2} = \\frac{e^{-3i}}{4}$\n   - Second-order pole at $z = 1$: $\\text{Res}(f, 1) = e^3$\n\n2. **Sum of Residues**:\n   $$\\sum \\text{Res} = e^3 + \\frac{e^{3i} + e^{-3i}}{4} = e^3 + \\frac{1}{2}\\cos(3)$$\n\n3. **Application of Residue Theorem**:\n   $$\\ointctrclockwise_{|z|=2} f(z) \\, dz = 2\\pi i \\left(e^3 + \\frac{1}{2}\\cos(3)\\right)$$\n\n*Mastery Tip:* Always factor quadratic terms $(z^2+1) = (z-i)(z+i)$ before taking limits!",
                "latex": "\\ointctrclockwise_{C} f(z) \\, dz = 2\\pi i \\sum_{k=1}^n \\text{Res}(f, z_k)",
                "is_verified": True,
                "sub_replies": [
                    {
                        "author_idx": 0,
                        "content": "The combination of the Euler identity $\\frac{e^{3i}+e^{-3i}}{2} = \\cos(3)$ is such an elegant touch. Exactly what my professor expects on the rubric.",
                    }
                ],
            },
            {
                "author_idx": 7,
                "content": "Thanks everyone, this broke down the exact hurdle I had with the second-order derivative term!",
            },
        ],
    },
    {
        "title": "Why does an RLC series circuit reach maximum current at resonance? Intuitive explanation needed",
        "track": "Physics",
        "syllabus_tag": "Electrodynamics & AC Circuits",
        "content": "I understand the algebraic proof that $X_L = X_C \\implies Z = R$, but conceptually, what is physically happening between the magnetic field in the inductor and the electric field in the capacitor at resonance?",
        "latex_content": "Z = \\sqrt{R^2 + \\left(\\omega L - \\frac{1}{\\omega C}\\right)^2} \\quad \\implies \\quad \\omega_0 = \\frac{1}{\\sqrt{LC}}",
        "tags": ["Physics", "ACCircuits", "Resonance", "Engineering"],
        "media_type": "single",
        "media_keys": ["circuit"],
        "is_question": True,
        "replies": [
            {
                "author_idx": 0,
                "content": "Think of it like a child on a playground swing! At resonance, the energy stored in the capacitor's electric field transfers completely into the inductor's magnetic field and back every half-cycle, precisely in phase with the AC driving voltage. The reactive components effectively cancel each other's impedance out.",
                "sub_replies": [
                    {
                        "author_idx": 8,
                        "content": "The swing analogy is brilliant Dr. Adebayo. So the source only has to do work against the internal resistance $R$ to maintain oscillations!",
                    }
                ],
            },
            {
                "is_ai": True,
                "content": "**Syllabot Pedagogical Breakdown:**\n\nAt the resonant frequency $\\omega_0 = \\frac{1}{\\sqrt{LC}}$:\n1. The voltage across the inductor leads current by $+90^\\circ$: $V_L = j\\omega L I$\n2. The voltage across the capacitor lags current by $-90^\\circ$: $V_C = \\frac{I}{j\\omega C} = -j\\frac{1}{\\omega C}I$\n3. Because $V_L + V_C = 0$ at all times during resonance, the total reactive voltage drop is zero, allowing current $I = \\frac{V_{in}}{R}$ to peak at its theoretical maximum.",
                "latex": "V_{net} = V_R + j(V_L - V_C) = V_R",
                "is_verified": True,
            },
        ],
    },
    {
        "title": "Dijkstra vs A* Algorithm: When should you NOT use Euclidean heuristic?",
        "track": "Computer Science",
        "syllabus_tag": "Algorithms & Graph Theory",
        "content": "We've been benchmarking graph traversal algorithms for large grid maps with dynamic obstacles and high-dimensional states. In what specific topologies does Euclidean distance fail or perform worse than Manhattan or diagonal Chebyshev heuristics?",
        "latex_content": "h(n) = \\sqrt{(x_n - x_{goal})^2 + (y_n - y_{goal})^2} \\le c(n, goal)",
        "tags": ["ComputerScience", "Algorithms", "GraphTheory", "AI"],
        "media_type": "none",
        "media_keys": [],
        "is_question": True,
        "replies": [
            {
                "author_idx": 4,
                "content": "Euclidean distance is only admissible when movement is continuous in any angle. If your agent is restricted to 4-directional grid movement (North, South, East, West), Euclidean distance underestimates the true step cost too drastically! Manhattan distance $h(n) = |\\Delta x| + |\\Delta y|$ provides a much tighter admissible heuristic.",
                "sub_replies": [
                    {
                        "author_idx": 9,
                        "content": "Exactly! If you use Euclidean on a 4-connected grid, A* expands way more nodes than necessary because $h(n)$ is too optimistic. For 8-directional grids with diagonal costs $\\sqrt{2}$, Octile heuristic is optimal.",
                    },
                    {
                        "author_idx": 4,
                        "content": "Here is the exact formula for Octile distance:\n$$h(n) = D(\\Delta x + \\Delta y) + (D_2 - 2D)\\min(\\Delta x, \\Delta y)$$\nwhere $D=1$ and $D_2 = \\sqrt{2}$.",
                    },
                ],
            },
            {
                "is_ai": True,
                "content": "### Heuristic Selection Rubric for A*\n\n| Grid Constraint | Optimal Admissible Heuristic | Over-estimation Risk |\n| :--- | :--- | :--- |\n| **4-Directional** | Manhattan Distance ($L_1$ Norm) | None (Strictly Admissible) |\n| **8-Directional** | Octile / Chebyshev Distance | None |\n| **Continuous Any-Angle** | Euclidean Distance ($L_2$ Norm) | None |\n| **Non-Euclidean / Graph** | Landmark Distance (ALT Algorithm) | None |",
                "is_verified": True,
            },
        ],
    },
    {
        "title": "High-Yield JAMB/WAEC Physics: 3-Second Shortcut for Projectile Range & Max Height Ratios",
        "track": "JAMB",
        "syllabus_tag": "Mechanics & Kinematics",
        "content": "Sharing a high-yield derivation that saved me so much time during mock exams! When a projectile is launched such that maximum height equals horizontal range ($H = R$), the launch angle is always $\\theta = \\arctan(4) \\approx 75.96^\\circ$. Here is the full relationship:",
        "latex_content": "\\frac{H}{R} = \\frac{u^2 \\sin^2\\theta / 2g}{u^2 \\sin(2\\theta) / g} = \\frac{\\sin^2\\theta}{2(2\\sin\\theta\\cos\\theta)} = \\frac{1}{4}\\tan\\theta",
        "tags": ["JAMB", "WAEC", "Physics", "ExamShortcuts", "Mechanics"],
        "media_type": "single",
        "media_keys": ["physics_mechanics"],
        "is_question": False,
        "replies": [
            {
                "author_idx": 6,
                "content": "This is pure gold Chinedu! In WAEC 2024 Question 14 they asked for the ratio $H/R$ when launch angle is $45^\\circ$. Using $\\frac{1}{4}\\tan(45^\\circ) = 1/4$, you get $R = 4H$ instantly in 2 seconds without drawing parabolas.",
                "sub_replies": [
                    {
                        "author_idx": 3,
                        "content": "Adding this formula directly to my study flashcard deck. Thanks for writing out the step-by-step cancellation!",
                    }
                ],
            },
            {
                "author_idx": 0,
                "content": "Excellent conceptual derivation. Notice also that complementary angles $(\\theta$ and $90^\\circ - \\theta)$ yield identical ranges $R$, but their maximum heights satisfy $H_1 H_2 = \\frac{R^2}{16}$.",
            },
        ],
    },
    {
        "title": "Action Potential in Cardiac Myocytes: Why is Phase 2 (Plateau) physiologically necessary?",
        "track": "Medicine",
        "syllabus_tag": "Cardiovascular Physiology",
        "content": "Unlike skeletal muscle fibers where action potentials last 1-2 ms, ventricular myocytes have a sustained 200-300 ms plateau phase (Phase 2). What ionic conductances maintain this plateau, and what disastrous mechanical event would happen to the heart if Phase 2 were absent?",
        "latex_content": "I_{net} = I_{Ca,L} - (I_{Kr} + I_{Ks}) \\approx 0 \\implies \\frac{dV_m}{dt} \\approx 0",
        "tags": ["Medicine", "Cardiology", "Physiology", "USMLE", "ActionPotential"],
        "media_type": "single",
        "media_keys": ["brain_synapse"],
        "is_question": True,
        "replies": [
            {
                "author_idx": 3,
                "content": "Phase 2 is maintained by a delicate balance: inward calcium influx via L-type $Ca^{2+}$ channels (DHPR) matches outward potassium efflux ($I_{Kr}, I_{Ks}$). If this prolonged refractory period didn't exist, the heart could undergo tetanic contraction (cramping), which would completely stop ventricular filling and cause fatal cardiac arrest!",
                "is_verified": True,
                "sub_replies": [
                    {
                        "author_idx": 5,
                        "content": "Also, the calcium entering during Phase 2 triggers Calcium-Induced Calcium Release (CICR) from the sarcoplasmic reticulum via Ryanodine receptors (RyR2), initiating the actual actin-myosin power stroke!",
                    },
                    {
                        "author_idx": 3,
                        "content": "Exactly Fatima! That's why Calcium Channel Blockers (like Verapamil or Diltiazem) decrease inotropy by shortening Phase 2.",
                    },
                ],
            },
            {
                "is_ai": True,
                "content": "**Syllabot Clinical Summary (Phase 0 to 4):**\n- **Phase 0:** Rapid depolarization (Fast voltage-gated $Na^+$ channels open)\n- **Phase 1:** Early repolarization (Transient outward $K^+$ current, $I_{to}$)\n- **Phase 2:** Plateau (L-type $Ca^{2+}$ influx balances delayed rectifier $K^+$ efflux)\n- **Phase 3:** Rapid repolarization (Inward rectifier $K^+$ channels open, $Ca^{2+}$ channels inactivate)\n- **Phase 4:** Resting membrane potential ($\approx -90\\text{ mV}$ established by $Na^+/K^+$ ATPase)",
            },
        ],
    },
    {
        "title": "Reaction mechanism of Michaelis-Menten Enzyme Kinetics with competitive vs non-competitive inhibition",
        "track": "Chemistry",
        "syllabus_tag": "Biochemistry & Enzymology",
        "content": "Can someone clarify how the Lineweaver-Burk double reciprocal plot changes under uncompetitive vs non-competitive inhibition? I keep mixing up the y-intercept and x-intercept shifts.",
        "latex_content": "\\frac{1}{V_0} = \\frac{K_m}{V_{max}} \\cdot \\frac{1}{[S]} + \\frac{1}{V_{max}}",
        "tags": ["Chemistry", "Biochemistry", "EnzymeKinetics", "LineweaverBurk"],
        "media_type": "multiple",
        "media_keys": ["lab_chemistry", "study_notes"],
        "is_question": True,
        "replies": [
            {
                "author_idx": 5,
                "content": "Here is an easy visual mnemonic to never confuse them again:\n\n1. **Competitive:** Lines intersect on the **Y-axis** ($V_{max}$ unchanged, $K_m$ increases).\n2. **Non-competitive:** Lines intersect on the **negative X-axis** ($K_m$ unchanged, $V_{max}$ decreases).\n3. **Uncompetitive:** Lines are strictly **parallel** (both $K_m$ and $V_{max}$ decrease proportionally).",
                "is_verified": True,
                "sub_replies": [
                    {
                        "author_idx": 7,
                        "content": "The parallel lines for uncompetitive is such a clean visual. That means slope $\\frac{K_m}{V_{max}}$ remains constant!",
                    }
                ],
            },
            {
                "is_ai": True,
                "content": "### Lineweaver-Burk Diagnostic Cheat Sheet\n\n- **X-Intercept:** $-\\frac{1}{K_m}$\n- **Y-Intercept:** $\\frac{1}{V_{max}}$\n- **Slope:** $\\frac{K_m}{V_{max}}$\n\nUnder **uncompetitive inhibition**, the inhibitor binds exclusively to the enzyme-substrate complex $[ES]$, decreasing both apparent parameters by factor $\\alpha'$:\n$$V_{max}^{app} = \\frac{V_{max}}{\\alpha'}, \\quad K_m^{app} = \\frac{K_m}{\\alpha'}$$\nHence slope remains invariant!",
            },
        ],
    },
    {
        "title": "SAT Math: Geometry & Inscribed Circles in Right Triangles Formula Shortcut",
        "track": "SAT",
        "syllabus_tag": "Plane Geometry",
        "content": "For any right triangle with legs $a, b$ and hypotenuse $c$, the radius $r$ of its incircle (inscribed circle) is given by this exact shortcut formula without needing Heron's theorem:",
        "latex_content": "r = \\frac{a + b - c}{2}",
        "tags": ["SAT", "Math", "Geometry", "Triangles", "Shortcuts"],
        "media_type": "none",
        "media_keys": [],
        "is_question": False,
        "replies": [
            {
                "author_idx": 7,
                "content": "Example: For a 3-4-5 right triangle, $r = \\frac{3 + 4 - 5}{2} = \\frac{2}{2} = 1$. Instant answer in under 5 seconds!",
                "sub_replies": [
                    {
                        "author_idx": 6,
                        "content": "Works on a 5-12-13 triangle too: $r = \\frac{5 + 12 - 13}{2} = 2$. Pure time saver!",
                    }
                ],
            },
            {
                "author_idx": 2,
                "content": "Proof is super clean too: tangent line segments from external vertices to the incircle have equal lengths $(a-r) + (b-r) = c \\implies a + b - 2r = c$.",
            },
        ],
    },
    {
        "title": "Derivation of Euler's Formula e^(i theta) = cos(theta) + i sin(theta) from Taylor Series",
        "track": "Mathematics",
        "syllabus_tag": "Calculus & Mathematical Analysis",
        "content": "Sharing the formal Taylor series expansion proof that unifies trigonometry, exponential growth, and complex numbers into Euler's identity. Here is the algebraic step breakdown:",
        "latex_content": "e^{i\\theta} = \\sum_{n=0}^{\\infty} \\frac{(i\\theta)^n}{n!} = \\left(1 - \\frac{\\theta^2}{2!} + \\frac{\\theta^4}{4!} - \\dots\\right) + i\\left(\\theta - \\frac{\\theta^3}{3!} + \\frac{\\theta^5}{5!} - \\dots\\right) = \\cos\\theta + i\\sin\\theta",
        "tags": ["Calculus", "EulerFormula", "TaylorSeries", "PureMath"],
        "media_type": "single",
        "media_keys": ["calculus_board"],
        "is_question": False,
        "replies": [
            {
                "author_idx": 1,
                "content": "Setting $\\theta = \\pi$ yields $e^{i\\pi} + 1 = 0$, connecting the five most fundamental constants of mathematics: $0, 1, e, i, \\pi$. Never gets old!",
            },
            {
                "is_ai": True,
                "content": "**Syllabot Insight:**\nThis identity also allows computing derivatives and integrals of oscillating signals in linear systems and quantum mechanics with zero trigonometry product-to-sum identities: $\\frac{d}{dt} e^{i\\omega t} = i\\omega e^{i\\omega t}$.",
            },
        ],
    },
]

def make_supabase_request(url: str, anon_key: str, method: str = "GET", data: dict = None, service_key: str = None):
    """Executes a REST call to Supabase PostgREST API."""
    req = request.Request(url, method=method)
    auth_bearer = service_key or anon_key
    req.add_header("apikey", anon_key)
    req.add_header("Authorization", f"Bearer {auth_bearer}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "return=representation")

    encoded_data = json.dumps(data).encode("utf-8") if data is not None else None
    try:
        with request.urlopen(req, data=encoded_data, timeout=15) as response:
            res_body = response.read().decode("utf-8")
            return json.loads(res_body) if res_body else None
    except error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"[HTTP {e.code}] Error calling {url}: {err_msg}")
        return None
    except Exception as ex:
        print(f"[Network Exception] {ex}")
        return None

def generate_and_seed_forum(
    post_count: int = 12,
    min_replies: int = 2,
    max_replies: int = 4,
    min_sub_replies: int = 1,
    max_sub_replies: int = 3,
    api_url: str = DEFAULT_API_URL,
    anon_key: str = DEFAULT_ANON_KEY,
    service_key: str = None,
):
    print("=" * 70)
    print(f"🚀 KORTEX FORUM SEEDING GENERATOR")
    print(f"Targeting: {api_url}")
    print(f"Generating {post_count} realistic posts with dynamic replies & nested threads...")
    print("=" * 70)

    total_posts_created = 0
    total_replies_created = 0
    total_sub_replies_created = 0

    posts_endpoint = f"{api_url}/rest/v1/forum_posts"
    replies_endpoint = f"{api_url}/rest/v1/forum_replies"

    now = datetime.datetime.now(datetime.timezone.utc)

    for p_idx in range(post_count):
        template = POST_TEMPLATES[p_idx % len(POST_TEMPLATES)]
        author_persona = PERSONAS[p_idx % len(PERSONAS)]
        
        # Build media URLs based on template specification
        media_urls = []
        if template["media_type"] == "single" and template.get("media_keys"):
            key = template["media_keys"][0]
            if key in ACADEMIC_IMAGES:
                media_urls.append(ACADEMIC_IMAGES[key])
        elif template["media_type"] == "multiple" and template.get("media_keys"):
            for k in template["media_keys"]:
                if k in ACADEMIC_IMAGES:
                    media_urls.append(ACADEMIC_IMAGES[k])
        
        # Spread timestamps organically over the last 1-14 days
        days_ago = random.uniform(0.5, 12.0)
        post_time = now - datetime.timedelta(days=days_ago)
        post_time_iso = post_time.isoformat()

        post_id = str(uuid.uuid4())
        upvotes = random.randint(4, 48)
        downvotes = random.randint(0, 2)

        post_payload = {
            "id": post_id,
            "title": template["title"] if p_idx < len(POST_TEMPLATES) else f"{template['title']} (Discussion #{p_idx+1})",
            "content": template["content"],
            "track": template["track"],
            "syllabus_tag": template["syllabus_tag"],
            "latex_content": template.get("latex_content"),
            "author_id": None, # Stored with persona name for public view
            "author_name": author_persona["name"],
            "author_avatar": author_persona["avatar"],
            "tags": template.get("tags", ["STEM", "Study"]),
            "media_urls": media_urls,
            "is_question": template.get("is_question", True),
            "is_verified_solution": False,
            "upvotes": upvotes,
            "downvotes": downvotes,
            "replies_count": 0,
            "created_at": post_time_iso,
            "updated_at": post_time_iso,
        }

        print(f"\n[Post {p_idx+1}/{post_count}] Creating: \"{post_payload['title'][:55]}...\"")
        print(f"  • Track: {post_payload['track']} | Images: {len(media_urls)} | Author: {author_persona['name']}")
        
        post_res = make_supabase_request(posts_endpoint, anon_key, method="POST", data=post_payload, service_key=service_key)
        if not post_res:
            print("  ⚠️ Failed to insert post. Skipping replies for this post.")
            continue

        total_posts_created += 1

        # Process top-level replies
        template_replies = template.get("replies", [])
        num_replies = random.randint(min_replies, max_replies)
        has_verified_solution_in_post = False
        post_reply_count = 0

        for r_idx in range(max(len(template_replies), num_replies)):
            r_data = template_replies[r_idx % len(template_replies)] if template_replies else {}
            
            is_ai_reply = r_data.get("is_ai", False)
            if is_ai_reply:
                rep_author = SYLLABOT_PERSONA
            else:
                persona_idx = r_data.get("author_idx", (p_idx + r_idx + 1) % len(PERSONAS))
                rep_author = PERSONAS[persona_idx]

            reply_id = str(uuid.uuid4())
            reply_time = post_time + datetime.timedelta(minutes=random.randint(15, 360))
            is_verified = r_data.get("is_verified", False) and not has_verified_solution_in_post

            if is_verified:
                has_verified_solution_in_post = True

            reply_payload = {
                "id": reply_id,
                "post_id": post_id,
                "parent_reply_id": None,
                "author_id": None,
                "author_name": rep_author["name"],
                "author_avatar": rep_author["avatar"],
                "content": r_data.get("content", "I worked through this step as well and got the exact same result."),
                "latex_content": r_data.get("latex", None),
                "is_verified_solution": is_verified,
                "upvotes": random.randint(3, 32),
                "downvotes": 0,
                "created_at": reply_time.isoformat(),
            }

            rep_res = make_supabase_request(replies_endpoint, anon_key, method="POST", data=reply_payload, service_key=service_key)
            if rep_res:
                total_replies_created += 1
                post_reply_count += 1
                status_badge = " [⭐ VERIFIED SOLUTION]" if is_verified else ""
                ai_badge = " [🤖 SYLLABOT AI]" if is_ai_reply else ""
                print(f"    ↳ Reply by {rep_author['name']}{ai_badge}{status_badge}")

                # Process nested sub-replies (threads)
                sub_list = r_data.get("sub_replies", [])
                if sub_list or random.random() < 0.65:
                    num_subs = len(sub_list) if sub_list else random.randint(min_sub_replies, max_sub_replies)
                    for s_idx in range(num_subs):
                        s_data = sub_list[s_idx % len(sub_list)] if sub_list else {}
                        sub_author_idx = s_data.get("author_idx", (persona_idx + s_idx + 2) % len(PERSONAS)) if not is_ai_reply else (p_idx % len(PERSONAS))
                        sub_author = PERSONAS[sub_author_idx]
                        sub_time = reply_time + datetime.timedelta(minutes=random.randint(5, 120))

                        sub_payload = {
                            "id": str(uuid.uuid4()),
                            "post_id": post_id,
                            "parent_reply_id": reply_id,
                            "author_id": None,
                            "author_name": sub_author["name"],
                            "author_avatar": sub_author["avatar"],
                            "content": s_data.get("content", "Thanks for the clarification! That made the concept crystal clear."),
                            "latex_content": s_data.get("latex", None),
                            "is_verified_solution": False,
                            "upvotes": random.randint(1, 14),
                            "downvotes": 0,
                            "created_at": sub_time.isoformat(),
                        }

                        sub_res = make_supabase_request(replies_endpoint, anon_key, method="POST", data=sub_payload, service_key=service_key)
                        if sub_res:
                            total_sub_replies_created += 1
                            post_reply_count += 1
                            print(f"        ↳ Sub-reply by {sub_author['name']}")

        # Update post replies_count and verification status
        update_payload = {
            "replies_count": post_reply_count,
            "is_verified_solution": has_verified_solution_in_post,
        }
        patch_url = f"{posts_endpoint}?id=eq.{post_id}"
        make_supabase_request(patch_url, anon_key, method="PATCH", data=update_payload, service_key=service_key)

    print("\n" + "=" * 70)
    print("✅ FORUM SEEDING COMPLETED SUCCESSFULLY!")
    print(f"📊 Summary Statistics:")
    print(f"   • Posts Created: {total_posts_created}")
    print(f"   • Top-Level Replies: {total_replies_created}")
    print(f"   • Nested Sub-Replies: {total_sub_replies_created}")
    print(f"   • Total Interactions: {total_posts_created + total_replies_created + total_sub_replies_created}")
    print("=" * 70)

def main():
    parser = argparse.ArgumentParser(description="Seed Kortex Supabase Forum with realistic academic discussions.")
    parser.add_argument("--posts", type=int, default=12, help="Number of forum posts to generate (default: 12)")
    parser.add_argument("--min-replies", type=int, default=2, help="Minimum top-level replies per post (default: 2)")
    parser.add_argument("--max-replies", type=int, default=4, help="Maximum top-level replies per post (default: 4)")
    parser.add_argument("--min-sub-replies", type=int, default=1, help="Minimum nested replies per thread (default: 1)")
    parser.add_argument("--max-sub-replies", type=int, default=3, help="Maximum nested replies per thread (default: 3)")
    parser.add_argument("--api-url", type=str, default=DEFAULT_API_URL, help="Supabase API URL")
    parser.add_argument("--anon-key", type=str, default=DEFAULT_ANON_KEY, help="Supabase Anon Key")
    parser.add_argument("--service-key", type=str, default=None, help="Optional Supabase Service Role Key")

    args = parser.parse_args()

    generate_and_seed_forum(
        post_count=args.posts,
        min_replies=args.min_replies,
        max_replies=args.max_replies,
        min_sub_replies=args.min_sub_replies,
        max_sub_replies=args.max_sub_replies,
        api_url=args.api_url,
        anon_key=args.anon_key,
        service_key=args.service_key,
    )

if __name__ == "__main__":
    main()
