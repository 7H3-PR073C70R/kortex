#!/usr/bin/env python3
"""
Kortex Dynamic Forum Seeding & Discussion Generator
====================================================
Generates 100% unique, organic, highly engaging discussions on every run using Ollama.
Covers both universal student experiences (that every student from every track relates to)
and fascinating track-specific paradoxes, debates, and epiphanies.

Features:
- Full database cleanup capability (--clean, --clean-only).
- Zero repetitive boilerplate: No canned formulaic openers.
- Varied styles: Debates, burning conceptual doubts, relatable confessions, practical study hacks.
- Cross-track universal topics (focus, burnout, sleep, exam anxiety, active recall, note systems)
  alongside field-specific curiosities (CS, Physics, Math, Medicine, Chemistry, WAEC, JAMB, SAT).
- Multi-tier conversational replies (configurable --reply-depth up to 4 levels).
- Authentic, diverse student & mentor personas.
- Syllabot AI pedagogical breakdowns.
- Contextual Unsplash image attachments and LaTeX math/chemical rendering.
"""

import sys
import os
import json
import uuid
import random
import argparse
import datetime
import subprocess
from urllib import request, error

# ==============================================================================
# 1. Configuration & Credentials
# ==============================================================================

DEFAULT_API_URL = "https://mongizqfijuhycdxltpw.supabase.co"
DEFAULT_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpenFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMjk0ODksImV4cCI6MjEwMzcwNTQ4OX0."
    "WdbPP0hWHnm2P7IWOOPOPv8emJsNql2jf5z6XnPa0wg"
)
DEFAULT_OLLAMA_URL = "http://localhost:11434"

# ==============================================================================
# 2. Authentic Personas
# ==============================================================================

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
        "role": "CS & Systems Student",
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
    {
        "name": "Kenechukwu Okafor",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&auto=format&fit=crop&q=80",
        "role": "UTME 345+ High Flyer",
        "track": "JAMB",
    },
    {
        "name": "Chloe Dupont",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80",
        "role": "Pure Mathematics Major",
        "track": "Mathematics",
    },
    {
        "name": "Tariq Morales",
        "avatar": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150&auto=format&fit=crop&q=80",
        "role": "Bioengineering Junior",
        "track": "Medicine",
    },
    {
        "name": "Maya Patel",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&auto=format&fit=crop&q=80",
        "role": "Cognitive Science Fellow",
        "track": "General",
    },
]

SYLLABOT_PERSONA = {
    "name": "Syllabot AI",
    "avatar": "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=150&auto=format&fit=crop&q=80",
    "role": "Adaptive AI Tutor",
}

# ==============================================================================
# 3. Media Assets
# ==============================================================================

ACADEMIC_IMAGES = {
    "study_desk": "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&auto=format&fit=crop&q=80",
    "library": "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=800&auto=format&fit=crop&q=80",
    "calculus_board": "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800&auto=format&fit=crop&q=80",
    "lab_chemistry": "https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=800&auto=format&fit=crop&q=80",
    "circuit": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80",
    "brain_synapse": "https://images.unsplash.com/photo-1559757175-5700dde675bc?w=800&auto=format&fit=crop&q=80",
    "code_editor": "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80",
    "physics_mechanics": "https://images.unsplash.com/photo-1509228468518-180dd4864904?w=800&auto=format&fit=crop&q=80",
    "microscope": "https://images.unsplash.com/photo-1579154204601-01588f351e67?w=800&auto=format&fit=crop&q=80",
    "network": "https://images.unsplash.com/photo-1504639725590-34d0984388bd?w=800&auto=format&fit=crop&q=80",
}

# ==============================================================================
# 4. Spontaneous Topic Ideas Pool (Universal & Track-Specific)
# ==============================================================================

# Universal topics relatable to ALL students across every exam and major
UNIVERSAL_TOPICS = [
    {
        "track": "General",
        "tag": "Exam Psychology & Mindset",
        "angle": "Overcoming the mid-exam panic freeze when question 1 looks completely unrecognizable",
        "context": "Has anyone else sat down for a timed exam, read the first problem, and felt their brain temporarily wipe clean? How do you reset in 30 seconds without spiraling?",
        "media_key": "study_desk",
    },
    {
        "track": "General",
        "tag": "Study Systems & Productivity",
        "angle": "All-nighter vs 8-hour sleep before an important test — the science of cognitive reboot",
        "context": "Debate: Does pulling a late night before test day ever actually pay off, or does sleep debt destroy your working memory so badly that extra cramming is pointless?",
        "media_key": "library",
    },
    {
        "track": "General",
        "tag": "Memory & Cognitive Science",
        "angle": "Active recall & spaced repetition vs passive re-reading and highlighters",
        "context": "Switched from highlighting textbooks to active recall with self-testing. It feels 5x harder in the moment, but the retention difference is insane. Why do schools still teach passive reading?",
        "media_key": "study_desk",
    },
    {
        "track": "General",
        "tag": "Focus & Flow States",
        "angle": "Pomodoro timing: Why 25/5 is too short for deep technical problem solving",
        "context": "For intensive derivations, proofs, or complex coding, 25 minutes cuts off your flow state right when your brain warms up. Who here uses 50/10 or 90-minute ultradian rhythm blocks?",
        "media_key": "study_desk",
    },
    {
        "track": "General",
        "tag": "Study Environment",
        "angle": "Lo-fi beats vs ambient rain vs absolute dead silence for deep concentration",
        "context": "What audio environment actually lets you solve high-focus problems? Some people swear by video game soundtracks, others can't even stand a ticking clock.",
        "media_key": "library",
    },
    {
        "track": "General",
        "tag": "Test Taking Strategies",
        "angle": "The psychological trap of changing your first intuitive answer on multiple-choice questions",
        "context": "Every time I go back and change an answer in the last 5 minutes of a test, my first gut instinct was right 80% of the time. What is your personal rule for when to change an answer?",
        "media_key": "study_desk",
    },
    {
        "track": "General",
        "tag": "Mental Models & Learning",
        "angle": "The Feynman Technique: Explaining complex ideas to non-technical friends",
        "context": "The ultimate test of understanding isn't whether you can recite the textbook definition — it's whether you can explain it to your younger sibling without jargon.",
        "media_key": "study_desk",
    },
    {
        "track": "General",
        "tag": "Note-Taking & Tools",
        "angle": "Digital notes (iPad/Notion) vs good old tactile pen and paper for working memory",
        "context": "Digital notes are great for searchability, but for working through difficult derivations, writing by hand on scratch paper activates spatial memory in a totally different way.",
        "media_key": "library",
    },
    {
        "track": "General",
        "tag": "Academic Burnout",
        "angle": "Recognizing early burnout before your brain forces an involuntary shutdown",
        "context": "How do you know when you need to push through temporary friction vs when you genuinely need to shut your laptop and take a full day off to avoid total burnout?",
        "media_key": "study_desk",
    },
]

# Track-specific topics with natural curiosities, debates, and epiphanies
TRACK_TOPICS_POOL = [
    {
        "track": "Computer Science",
        "tag": "Algorithms & Reality",
        "angle": "Why do introductory CS courses teach recursion using Fibonacci when it's literally O(2^n)?",
        "context": "Teaching naive recursion on Fibonacci is basically teaching students how to write accidental exponential time bombs. Iterative or memoized DP should be the default from day one.",
        "media_key": "code_editor",
    },
    {
        "track": "Computer Science",
        "tag": "Debugging & Software Engineering",
        "angle": "The most agonizing bug you spent 3 days debugging that turned out to be a 1-character typo",
        "context": "Share your most humbling debugging war story. When you finally found the issue, did you feel like a genius or did you just stare at the ceiling for 10 minutes?",
        "media_key": "code_editor",
    },
    {
        "track": "Computer Science",
        "tag": "Systems & Concurrency",
        "angle": "Why off-by-one errors and race conditions are the true final bosses of software",
        "context": "There are only two hard things in Computer Science: cache invalidation, naming things, and off-by-one errors. Why is concurrent state management so unintuitive to human brains?",
        "media_key": "network",
    },
    {
        "track": "Physics",
        "tag": "Thermodynamics & Anomalies",
        "angle": "Why ice floats and why water density peaks at 4°C: The anomaly that saves all marine life",
        "context": "Almost all liquids become denser as they freeze and sink. If water did that, every lake and ocean would freeze from the bottom up and marine life would be extinct. Nature is wild.",
        "media_key": "physics_mechanics",
    },
    {
        "track": "Physics",
        "tag": "Relativity & Cosmology",
        "angle": "If nothing can travel faster than light, why is the observable universe expanding faster than light?",
        "context": "It breaks everyone's intuition at first: the speed limit c applies to objects traveling THROUGH space, not to the metric expansion of spacetime itself.",
        "media_key": "physics_mechanics",
    },
    {
        "track": "Physics",
        "tag": "Classical Mechanics",
        "angle": "Centrifugal force isn't a 'real' force, but why does it feel so undeniably real in a car turn?",
        "context": "Physics professors love to yell 'it's an apparent fictitious force caused by inertia!', but in a rotating non-inertial reference frame, treating it as real makes calculations so much easier.",
        "media_key": "circuit",
    },
    {
        "track": "Mathematics",
        "tag": "Number Theory & Logic",
        "angle": "Why 0.999... = 1 causes heated arguments in every single math study group",
        "context": "Whether you prove it via 1/3 = 0.333... or using geometric series S = a/(1-r), people resist the idea that two different decimal representations can equal the exact same real number.",
        "media_key": "calculus_board",
    },
    {
        "track": "Mathematics",
        "tag": "Mathematical Beauty",
        "angle": "What is the single most satisfying algebraic cancellation or proof you've ever worked through?",
        "context": "That moment when a terrifying 3-line fraction collapses down to 1 or 0 after 20 minutes of algebraic substitution. Pure dopamine.",
        "media_key": "calculus_board",
    },
    {
        "track": "Mathematics",
        "tag": "Foundations of Math",
        "angle": "Why isn't 1 considered a prime number? (The Fundamental Theorem of Arithmetic rescue)",
        "context": "If 1 were considered prime, every integer would have an infinite number of prime factorizations (e.g. 6 = 2 * 3 = 1 * 2 * 3 = 1 * 1 * 2 * 3), destroying unique factorization.",
        "media_key": "calculus_board",
    },
    {
        "track": "Medicine",
        "tag": "Physiology & Pharmacology",
        "angle": "Why caffeine loses its magic after a week: The cruel biology of adenosine receptor upregulation",
        "context": "Caffeine doesn't actually give you energy — it just blocks adenosine receptors from telling your brain you're tired. But then your brain creates MORE receptors in response. How do you cycle it?",
        "media_key": "brain_synapse",
    },
    {
        "track": "Medicine",
        "tag": "Clinical Anatomy",
        "angle": "Referred pain: Why a problem in your heart or gallbladder shows up in your left arm or shoulder",
        "context": "The embryonic development of sensory nerves sharing spinal cord segments creates bizarre cross-wiring. What are the best clinical mnemonics for memorizing referred pain maps?",
        "media_key": "brain_synapse",
    },
    {
        "track": "Chemistry",
        "tag": "Organic Chemistry",
        "angle": "Organic chemistry is 20% chemistry and 80% 3D spatial puzzle game",
        "context": "Once you realize electron arrows are just nucleophiles hunting down electrophiles and stereocenters are 3D Lego bricks, organic synthesis stops being about memorizing 200 reagents.",
        "media_key": "lab_chemistry",
    },
    {
        "track": "Chemistry",
        "tag": "Physical Chemistry",
        "angle": "Why adding salt to boiling pasta water doesn't actually cook it faster (Colligative properties reality check)",
        "context": "The boiling point elevation from a pinch of kitchen salt raises water temperature by maybe 0.04°C. You'd need a cup of salt to make any real cooking time difference!",
        "media_key": "lab_chemistry",
    },
    {
        "track": "JAMB",
        "tag": "CBT Tactics & Strategy",
        "angle": "The 60-second rule: When to flag a question and move on during UTME CBT exams",
        "context": "In JAMB CBT, all questions carry equal marks. Spending 4 minutes wrestling with one tricky question means you won't have time to answer 5 easy ones at the end. What is your pacing formula?",
        "media_key": "study_desk",
    },
    {
        "track": "JAMB",
        "tag": "Exam Prep & Mocks",
        "angle": "What single change took your mock test score from 210 to 280+?",
        "context": "Was it mastering time allocation across your 4 subjects, drilling past questions by topic, or eliminating careless math errors?",
        "media_key": "study_desk",
    },
    {
        "track": "WAEC",
        "tag": "WASSCE Theory & Marking",
        "angle": "Why WAEC examiners deduct marks even when your final numerical answer is 100% correct",
        "context": "Forgetting units in intermediate steps, skipping the formula statement, or not quoting theorem reasons in circle geometry. What marking scheme traps have cost you marks in mocks?",
        "media_key": "study_desk",
    },
    {
        "track": "WAEC",
        "tag": "Past Questions Strategy",
        "angle": "Practicing past questions: Is it better to solve year-by-year or topic-by-topic?",
        "context": "Topic-by-topic builds deep concept mastery, while year-by-year trains exam stamina and time management. How do you balance both in the last 2 months before finals?",
        "media_key": "study_desk",
    },
    {
        "track": "SAT",
        "tag": "Digital SAT Tactics",
        "angle": "Why the built-in Desmos graphing calculator on Digital SAT feels almost like a cheat code",
        "context": "From systems of nonlinear equations to finding vertex coordinates, students who master Desmos shortcuts can solve half the Module 2 math problems without touching scratch paper.",
        "media_key": "calculus_board",
    },
    {
        "track": "SAT",
        "tag": "Reading & Verbal Traps",
        "angle": "The 'sounds brilliant but is dead wrong' trap in SAT reading questions",
        "context": "How the test makers write enticing distractor choices that use smart vocabulary but violate one single factual detail from the passage.",
        "media_key": "library",
    },
    {
        "track": "Engineering",
        "tag": "Design & Real-World Physics",
        "angle": "Why airplane and ship windows are strictly rounded instead of square (The De Havilland Comet lesson)",
        "context": "Square window corners create massive stress concentration factors ($K_t$) where microscopic cracks propagate under cyclic cabin pressurization. Classic design lesson.",
        "media_key": "circuit",
    },
]

# Diverse post formats to enforce variety
POST_STYLES = [
    {
        "style": "debate",
        "prompt_instruction": "Frame the post as an open, thought-provoking debate. Present two contrasting viewpoints or methods, and ask the community which side they lean toward and why.",
    },
    {
        "style": "question",
        "prompt_instruction": "Frame the post as a genuine, curious student asking a conceptual question that they have been wrestling with. Avoid sounding helpless; sound smart, curious, and seeking intuitive clarity.",
    },
    {
        "style": "personal_experience",
        "prompt_instruction": "Frame the post as a student sharing a recent personal revelation or study breakthrough that saved them time or changed their perspective, inviting others to share theirs.",
    },
    {
        "style": "dilemma",
        "prompt_instruction": "Frame the post as a relatable academic dilemma (e.g. time crunch, balancing two heavy subjects, choosing the right study technique under pressure).",
    },
]

# ==============================================================================
# 5. Database Cleanup & Supabase REST Operations
# ==============================================================================

def clean_forum_database() -> bool:
    """Purges all forum posts and replies via cascading truncate."""
    print("\n" + "=" * 70)
    print("🧹 PURGING FORUM DATABASE (TRUNCATE CASCADE)")
    print("=" * 70)
    try:
        res = subprocess.run(
            ["supabase", "db", "query", "--linked", "TRUNCATE TABLE forum_replies, forum_posts CASCADE;"],
            capture_output=True,
            text=True,
            timeout=20,
        )
        if res.returncode == 0:
            print("✅ Successfully purged forum_replies and forum_posts tables.")
            return True
        else:
            print(f"⚠️ Supabase CLI returned error (exit code {res.returncode}): {res.stderr.strip() or res.stdout.strip()}")
    except Exception as ex:
        print(f"⚠️ Supabase CLI execution failed: {ex}")
    return False


def make_supabase_request(
    url: str,
    anon_key: str,
    method: str = "GET",
    data: dict = None,
    service_key: str = None,
):
    """Executes a REST call to Supabase PostgREST API."""
    req = request.Request(url, method=method)
    auth_bearer = service_key or anon_key
    req.add_header("apikey", anon_key)
    req.add_header("Authorization", f"Bearer {auth_bearer}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "return=representation")

    encoded_data = json.dumps(data).encode("utf-8") if data is not None else None
    try:
        with request.urlopen(req, data=encoded_data, timeout=20) as response:
            res_body = response.read().decode("utf-8")
            return json.loads(res_body) if res_body else None
    except error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"[HTTP {e.code}] Error calling {url}: {err_msg}")
        return None
    except Exception as ex:
        print(f"[Network Exception] {ex}")
        return None

# ==============================================================================
# 6. Ollama Local LLM Engine
# ==============================================================================

def check_ollama_status(ollama_url: str = DEFAULT_OLLAMA_URL) -> list:
    """Verifies Ollama connectivity and lists installed models."""
    try:
        req = request.Request(f"{ollama_url}/api/tags", method="GET")
        with request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return [m.get("name") for m in data.get("models", [])]
    except Exception:
        return []


def detect_best_model(installed_models: list, preferred_model: str = None) -> str:
    """Selects the best available Ollama model."""
    if preferred_model and preferred_model in installed_models:
        return preferred_model
    priority_order = [
        "qwen2.5-coder:7b",
        "qwen2.5:14b",
        "qwen2.5:7b",
        "granite3.2-vision:latest",
        "llama3.1:8b",
        "mistral:latest",
    ]
    for model in priority_order:
        if model in installed_models:
            return model
    return installed_models[0] if installed_models else "qwen2.5-coder:7b"


def query_ollama_json(
    prompt: str,
    model: str,
    ollama_url: str = DEFAULT_OLLAMA_URL,
    temperature: float = 0.88,
    timeout: int = 120,
) -> dict:
    """Sends generation request to Ollama with strict JSON formatting."""
    payload = {
        "model": model,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": temperature,
            "top_p": 0.92,
        },
    }
    req = request.Request(
        f"{ollama_url}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            raw_response = data.get("response", "").strip()
            
            # Clean up potential markdown formatting wrappers
            if raw_response.startswith("```json"):
                raw_response = raw_response[7:]
            if raw_response.startswith("```"):
                raw_response = raw_response[3:]
            if raw_response.endswith("```"):
                raw_response = raw_response[:-3]
            raw_response = raw_response.strip()

            return json.loads(raw_response)
    except Exception as ex:
        print(f"  ⚠️ Ollama generation exception: {ex}")
        return None

# ==============================================================================
# 7. Dynamic Non-Repetitive Prompt Architecture
# ==============================================================================

def build_dynamic_prompt(
    item: dict,
    style_spec: dict,
    reply_depth: int = 3,
    min_replies: int = 2,
    max_replies: int = 3,
) -> str:
    """
    Constructs a spontaneous, highly distinct prompt that avoids cliché openings
    and reflects genuine student life / academic community dialogue.
    """
    track = item["track"]
    syllabus_tag = item["tag"]
    angle = item["angle"]
    seed_context = item["context"]

    return f"""You are generating an authentic, original, highly engaging forum discussion post for Kortex, a premier academic learning platform.

Track: {track}
Syllabus / Domain Tag: {syllabus_tag}
Discussion Core Idea: {angle}
Background Inspiration: {seed_context}

Style Requirement:
{style_spec['prompt_instruction']}

STRICT NEGATIVE CONSTRAINTS (DO NOT VIOLATE):
- DO NOT use cliché openings like "I was solving question 14 of 2023 WASSCE...", "Let's dive into it!", "Hey everyone!", or "In this post I will discuss...".
- DO NOT sound like a robotic textbook, an advertisement, or a generic AI assistant.
- Sound like a real student, researcher, or mentor posting on a lively forum or Reddit r/studytips at 11 PM.
- Write with personality, natural flow, and genuine curiosity or insight.
- If relevant, include standard LaTeX equations (e.g. $formula$ or $$\\int ...$$).

REPLY REQUIREMENTS (Depth {reply_depth}):
- Provide between {min_replies} and {max_replies} top-level replies.
- One reply should be an insightful peer/mentor response with 'is_verified': true.
- One reply should be Syllabot AI with 'is_ai': true and 'author_role': 'syllabot', offering structured, supportive takeaways.
- Provide nested sub-replies (depth up to {reply_depth}) where the original author or a peer asks a follow-up nuance or shares their own counter-experience, and another person answers.

Return ONLY a valid JSON object matching this schema:
{{
  "title": "Fresh, catchy, natural title",
  "track": "{track}",
  "syllabus_tag": "{syllabus_tag}",
  "content": "Authentic, relatable body text reflecting the style and idea",
  "latex_content": null,
  "tags": ["Tag1", "Tag2"],
  "media_type": "single",
  "is_question": true,
  "replies": [
    {{
      "author_role": "peer",
      "content": "Rich, personal response sharing experience, insight, or debate",
      "latex_content": null,
      "is_verified": true,
      "is_ai": false,
      "replies": [
        {{
          "author_role": "author",
          "content": "Follow-up question, counter-point, or practical doubt",
          "latex_content": null,
          "is_verified": false,
          "is_ai": false,
          "replies": [
            {{
              "author_role": "mentor",
              "content": "Clarifying conclusion or practical takeaway resolving the dilemma",
              "latex_content": null,
              "is_verified": false,
              "is_ai": false,
              "replies": []
            }}
          ]
        }}
      ]
    }},
    {{
      "author_role": "syllabot",
      "content": "### Syllabot Key Takeaways\\nActionable cognitive science or study strategy breakdown.",
      "latex_content": null,
      "is_verified": false,
      "is_ai": true,
      "replies": []
    }}
  ]
}}
"""

# ==============================================================================
# 8. Forum Seeding Engine with Persona Mapping
# ==============================================================================

def select_author_persona(track: str) -> dict:
    """Picks a persona that matches or complements the track."""
    track_lower = track.lower()
    if track_lower in ("general", "all"):
        return random.choice(PERSONAS)
    matching = [p for p in PERSONAS if p["track"].lower() in track_lower or track_lower in p["track"].lower()]
    return random.choice(matching) if matching else random.choice(PERSONAS)


def insert_reply_tree(
    replies_list: list,
    post_id: str,
    parent_reply_id: str,
    base_time: datetime.datetime,
    posts_endpoint: str,
    replies_endpoint: str,
    anon_key: str,
    service_key: str,
    author_persona: dict,
    has_verified: bool,
    current_depth: int = 1,
    max_depth: int = 3,
) -> tuple:
    """Recursively inserts reply nodes into Supabase, maintaining proper parent_reply_id."""
    created_count = 0
    post_has_verified = has_verified

    for idx, rep in enumerate(replies_list):
        is_ai = rep.get("is_ai", False) or rep.get("author_role") == "syllabot"
        is_verified = rep.get("is_verified", False) and not post_has_verified

        if is_ai:
            rep_author = SYLLABOT_PERSONA
        elif current_depth == 1:
            # Different persona from author
            candidates = [p for p in PERSONAS if p["name"] != author_persona["name"]]
            rep_author = random.choice(candidates)
        elif current_depth == 2:
            # Often the author following up with a doubt/question
            if random.random() < 0.7:
                rep_author = author_persona
            else:
                rep_author = random.choice([p for p in PERSONAS if p["name"] != author_persona["name"]])
        else:
            candidates = [p for p in PERSONAS if p["name"] != author_persona["name"]]
            rep_author = random.choice(candidates)

        if is_verified:
            post_has_verified = True

        reply_id = str(uuid.uuid4())
        delta_minutes = random.randint(12, 50) * current_depth + (idx * 15)
        reply_time = base_time + datetime.timedelta(minutes=delta_minutes)
        upvotes = random.randint(12, 48) if is_verified else random.randint(3, 22)

        reply_payload = {
            "id": reply_id,
            "post_id": post_id,
            "parent_reply_id": parent_reply_id,
            "author_id": None,
            "author_name": rep_author["name"],
            "author_avatar": rep_author["avatar"],
            "content": rep.get("content", "Totally agree with this point."),
            "latex_content": rep.get("latex_content"),
            "is_verified_solution": is_verified,
            "upvotes": upvotes,
            "downvotes": 0,
            "created_at": reply_time.isoformat(),
        }

        res = make_supabase_request(
            replies_endpoint,
            anon_key,
            method="POST",
            data=reply_payload,
            service_key=service_key,
        )

        if res:
            created_count += 1
            indent = "    " * current_depth
            status_badge = " [⭐ VERIFIED SOLUTION]" if is_verified else ""
            ai_badge = " [🤖 SYLLABOT AI]" if is_ai else ""
            print(f"{indent}↳ [Depth {current_depth}] Reply by {rep_author['name']}{ai_badge}{status_badge}")

            child_replies = rep.get("replies") or rep.get("sub_replies") or []
            if child_replies and current_depth < max_depth:
                sub_count, post_has_verified = insert_reply_tree(
                    child_replies,
                    post_id=post_id,
                    parent_reply_id=reply_id,
                    base_time=reply_time,
                    posts_endpoint=posts_endpoint,
                    replies_endpoint=replies_endpoint,
                    anon_key=anon_key,
                    service_key=service_key,
                    author_persona=author_persona,
                    has_verified=post_has_verified,
                    current_depth=current_depth + 1,
                    max_depth=max_depth,
                )
                created_count += sub_count

    return created_count, post_has_verified


def seed_forum(
    post_count: int = 10,
    reply_depth: int = 3,
    min_replies: int = 2,
    max_replies: int = 3,
    tracks: list = None,
    api_url: str = DEFAULT_API_URL,
    anon_key: str = DEFAULT_ANON_KEY,
    service_key: str = None,
    ollama_url: str = DEFAULT_OLLAMA_URL,
    model_name: str = None,
    use_ollama: bool = True,
):
    """Main orchestrator for generating dynamic, diverse, non-repetitive discussions."""
    print("\n" + "=" * 70)
    print("🚀 KORTEX ADVANCED DYNAMIC FORUM GENERATOR")
    print(f"Target API: {api_url}")
    print(f"Generating {post_count} unique discussions | Depth: {reply_depth}")

    active_model = None
    if use_ollama:
        installed = check_ollama_status(ollama_url)
        if installed:
            active_model = detect_best_model(installed, model_name)
            print(f"🤖 Ollama Connected: Using model '{active_model}'")
        else:
            print("⚠️ Ollama unreachable, falling back to curated blueprints.")
            use_ollama = False

    posts_endpoint = f"{api_url}/rest/v1/forum_posts"
    replies_endpoint = f"{api_url}/rest/v1/forum_replies"

    now = datetime.datetime.now(datetime.timezone.utc)
    total_posts_created = 0
    total_replies_created = 0

    # Build balanced topic candidates pool:
    # Blend universal student life topics (~45%) with track-specific curiosities (~55%)
    candidates_pool = []
    
    if tracks:
        # User specified specific tracks
        filter_lower = [t.lower() for t in tracks]
        for t in TRACK_TOPICS_POOL:
            if t["track"].lower() in filter_lower:
                candidates_pool.append(t)
        # If General was requested or if pool is small, include universal
        if "general" in filter_lower or len(candidates_pool) < post_count:
            candidates_pool.extend(UNIVERSAL_TOPICS)
    else:
        # Full diversity mode: shuffle both
        shuffled_universal = list(UNIVERSAL_TOPICS)
        shuffled_track = list(TRACK_TOPICS_POOL)
        random.shuffle(shuffled_universal)
        random.shuffle(shuffled_track)

        # Alternate between universal and track-specific
        for i in range(max(len(shuffled_universal), len(shuffled_track))):
            if i < len(shuffled_universal):
                candidates_pool.append(shuffled_universal[i])
            if i < len(shuffled_track):
                candidates_pool.append(shuffled_track[i])

    random.shuffle(candidates_pool)
    print(f"Candidate Topic Pool Size: {len(candidates_pool)} items")
    print("=" * 70)

    for p_idx in range(post_count):
        topic_spec = candidates_pool[p_idx % len(candidates_pool)]
        style_spec = POST_STYLES[p_idx % len(POST_STYLES)]
        track = topic_spec["track"]
        author_persona = select_author_persona(track)

        generated_data = None
        if use_ollama and active_model:
            print(f"\n[Post {p_idx+1}/{post_count}] Generating via Ollama for [{track}] ({style_spec['style']})...")
            prompt = build_dynamic_prompt(
                item=topic_spec,
                style_spec=style_spec,
                reply_depth=reply_depth,
                min_replies=min_replies,
                max_replies=max_replies,
            )
            generated_data = query_ollama_json(prompt, active_model, ollama_url=ollama_url)

        if not generated_data:
            print(f"  • Using curated blueprint fallback for [{track}]")
            generated_data = {
                "title": topic_spec["angle"],
                "track": track,
                "syllabus_tag": topic_spec["tag"],
                "content": topic_spec["context"],
                "latex_content": None,
                "tags": [track, "Study", topic_spec["tag"].split()[0]],
                "media_type": "single",
                "is_question": True,
                "replies": [
                    {
                        "author_role": "peer",
                        "content": "This is so relatable. In my experience, setting clear boundaries between study sessions and rest was the game-changer.",
                        "is_verified": True,
                        "replies": [
                            {
                                "author_role": "author",
                                "content": "How did you stick to that boundary when deadlines were literally days away?",
                                "replies": [
                                    {
                                        "author_role": "mentor",
                                        "content": "Strict time-blocking and prioritizing the highest-yield 20% of the material.",
                                        "replies": [],
                                    }
                                ],
                            }
                        ],
                    },
                    {
                        "author_role": "syllabot",
                        "content": "### Syllabot Key Takeaways\n- Prioritize sleep for long-term memory consolidation.\n- Break marathon sessions into 50-minute focused blocks.",
                        "replies": [],
                    },
                ],
            }

        media_key = topic_spec.get("media_key", "study_desk")
        media_urls = [ACADEMIC_IMAGES[media_key]] if media_key in ACADEMIC_IMAGES else []

        days_ago = random.uniform(0.2, 12.0)
        post_time = now - datetime.timedelta(days=days_ago)
        post_id = str(uuid.uuid4())

        post_payload = {
            "id": post_id,
            "title": generated_data.get("title", topic_spec["angle"]),
            "content": generated_data.get("content", topic_spec["context"]),
            "track": track,
            "syllabus_tag": generated_data.get("syllabus_tag", topic_spec["tag"]),
            "latex_content": generated_data.get("latex_content"),
            "author_id": None,
            "author_name": author_persona["name"],
            "author_avatar": author_persona["avatar"],
            "tags": generated_data.get("tags", [track, "Community"]),
            "media_urls": media_urls,
            "is_question": generated_data.get("is_question", True),
            "is_verified_solution": False,
            "upvotes": random.randint(8, 52),
            "downvotes": random.randint(0, 2),
            "replies_count": 0,
            "created_at": post_time.isoformat(),
            "updated_at": post_time.isoformat(),
        }

        print(f"  • Title: \"{post_payload['title'][:65]}...\"")
        print(f"  • Author: {author_persona['name']} ({author_persona['role']})")

        post_res = make_supabase_request(
            posts_endpoint,
            anon_key,
            method="POST",
            data=post_payload,
            service_key=service_key,
        )

        if not post_res:
            print("  ⚠️ Failed to insert post. Skipping replies.")
            continue

        total_posts_created += 1

        replies_list = generated_data.get("replies", [])
        total_post_replies, has_verified_solution = insert_reply_tree(
            replies_list=replies_list,
            post_id=post_id,
            parent_reply_id=None,
            base_time=post_time,
            posts_endpoint=posts_endpoint,
            replies_endpoint=replies_endpoint,
            anon_key=anon_key,
            service_key=service_key,
            author_persona=author_persona,
            has_verified=False,
            current_depth=1,
            max_depth=reply_depth,
        )

        total_replies_created += total_post_replies

        patch_payload = {
            "replies_count": total_post_replies,
            "is_verified_solution": has_verified_solution,
        }
        patch_url = f"{posts_endpoint}?id=eq.{post_id}"
        make_supabase_request(patch_url, anon_key, method="PATCH", data=patch_payload, service_key=service_key)

    print("\n" + "=" * 70)
    print("✅ FORUM SEEDING GENERATION COMPLETE!")
    print(f"📊 Final Statistics:")
    print(f"   • Total Posts Created: {total_posts_created}")
    print(f"   • Total Replies & Sub-Replies: {total_replies_created}")
    print(f"   • Total Community Interactions: {total_posts_created + total_replies_created}")
    print("=" * 70 + "\n")

# ==============================================================================
# 9. CLI Entry Point
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Seed Kortex Forum with dynamic, relatable, non-repetitive AI-generated discussions."
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Purge all existing posts and replies from the database before seeding.",
    )
    parser.add_argument(
        "--clean-only",
        action="store_true",
        help="Only purge existing posts and replies from the database, then exit.",
    )
    parser.add_argument(
        "--posts",
        type=int,
        default=10,
        help="Number of forum posts to generate (default: 10)",
    )
    parser.add_argument(
        "--reply-depth",
        type=int,
        default=3,
        help="Maximum reply conversational depth tree (default: 3, range 1-4)",
    )
    parser.add_argument(
        "--min-replies",
        type=int,
        default=2,
        help="Minimum top-level replies per post (default: 2)",
    )
    parser.add_argument(
        "--max-replies",
        type=int,
        default=3,
        help="Maximum top-level replies per post (default: 3)",
    )
    parser.add_argument(
        "--tracks",
        nargs="+",
        default=None,
        help="Filter by track(s) (e.g. General WAEC JAMB 'Computer Science' Physics)",
    )
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Ollama model to use (default: auto-detected, prefers qwen2.5-coder:7b or qwen2.5:14b)",
    )
    parser.add_argument(
        "--ollama-url",
        type=str,
        default=DEFAULT_OLLAMA_URL,
        help="Ollama API base URL (default: http://localhost:11434)",
    )
    parser.add_argument(
        "--no-ollama",
        action="store_true",
        help="Disable Ollama and use blueprints only.",
    )
    parser.add_argument(
        "--api-url",
        type=str,
        default=DEFAULT_API_URL,
        help="Supabase API URL",
    )
    parser.add_argument(
        "--anon-key",
        type=str,
        default=DEFAULT_ANON_KEY,
        help="Supabase Anon Key",
    )
    parser.add_argument(
        "--service-key",
        type=str,
        default=None,
        help="Optional Supabase Service Role Key",
    )

    args = parser.parse_args()

    if args.clean or args.clean_only:
        clean_forum_database()
        if args.clean_only:
            print("Purge completed. Exiting.")
            sys.exit(0)

    seed_forum(
        post_count=args.posts,
        reply_depth=max(1, min(args.reply_depth, 4)),
        min_replies=args.min_replies,
        max_replies=args.max_replies,
        tracks=args.tracks,
        api_url=args.api_url,
        anon_key=args.anon_key,
        service_key=args.service_key,
        ollama_url=args.ollama_url,
        model_name=args.model,
        use_ollama=not args.no_ollama,
    )


if __name__ == "__main__":
    main()
