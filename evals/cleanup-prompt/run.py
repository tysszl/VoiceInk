"""Run cleanup-prompt variants against frozen cases with VoiceInk's production request.

Usage: python3 run.py [runs_per_variant] [cases_file] [results_file]
Layer 1 comes from AIPrompts.swift; the Dictionary block from the stored system-template.txt (set TEMPLATE to use a stored template whole). Reads cases (default cases.json) from the state dir; writes results (default results.json) there.
Key: VoiceInk's Cerebras key from the login keychain, read in-process and never printed.

Local models: ENDPOINT (an OpenAI-compatible chat URL; no key is sent), MODEL, TEMPERATURE (default 0.3),
LAYOUT=bare (the transcript as the whole user turn, as VoiceInk Refine sends it) or tagged (default, <TRANSCRIPT>),
WORKERS (default 4; use 1 to time a local model), EXTRA (JSON merged into the request body).
"""
import json, os, re, subprocess, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

STATE = os.path.expanduser("~/.local/state/evals/voiceink/cleanup-prompt")
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
CASES = sys.argv[2] if len(sys.argv) > 2 else "cases.json"
RESULTS = sys.argv[3] if len(sys.argv) > 3 else "results.json"
CEREBRAS = "https://api.cerebras.ai/v1/chat/completions"
ENDPOINT = os.environ.get("ENDPOINT", CEREBRAS)
LOCAL = ENDPOINT != CEREBRAS
MODEL = os.environ.get("MODEL", "qwen-3.8-27b")
TEMPERATURE = float(os.environ.get("TEMPERATURE", "0.3"))
BARE = os.environ.get("LAYOUT", "tagged") == "bare"

def key():
    return subprocess.run(["security", "find-generic-password", "-s", "com.prakashjoshipax.VoiceInk.Local",
                           "-a", "cerebrasAPIKey", "-w"], capture_output=True, text=True, check=True).stdout.strip()

def layer1_from_source():
    """AIPrompts.enhancementSystemTemplate as the current build sends it."""
    src = open(os.path.join(HERE, "../../VoiceInk/Core/Enhancement/AIPrompts.swift")).read()
    body = re.search(r'enhancementSystemTemplate = """\n(.*?)\n(\s*)"""', src, re.S)
    indent = body.group(2)
    return "\n".join(l[len(indent):] if l.startswith(indent) else l.lstrip() for l in body.group(1).split("\n"))

def current_template():
    """Layer 1 from source plus the Dictionary block from the stored production request."""
    stored = open(f"{STATE}/" + os.environ.get("TEMPLATE", "system-template.txt")).read()
    if os.environ.get("TEMPLATE"):
        return stored
    vocab = stored[stored.index("</SYSTEM_INSTRUCTIONS>") + len("</SYSTEM_INSTRUCTIONS>"):]
    return layer1_from_source() + vocab

def system_for(template, body):
    """A variant is prompt text (system instructions on) or {"text": ..., "system": false, "vocab": false}."""
    if isinstance(body, dict):
        if not body.get("vocab", True):
            return body["text"]
        if not body.get("system", True):
            vocab = template[template.index("</SYSTEM_INSTRUCTIONS>") + len("</SYSTEM_INSTRUCTIONS>"):]
            return body["text"] + vocab
        body = body["text"]
    pat = re.compile(r"(<TASK_INSTRUCTIONS>\n).*?(\n</TASK_INSTRUCTIONS>)", re.S)
    out, n = pat.subn(lambda m: m.group(1) + body + m.group(2), template, count=1)
    assert n == 1
    return out

def call(k, system, text):
    user = text if BARE else f"\n<TRANSCRIPT>\n{text}\n</TRANSCRIPT>"
    body = {"model": MODEL, "temperature": TEMPERATURE,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}
    if not LOCAL:
        body["reasoning_effort"] = "none"
    body.update(json.loads(os.environ.get("EXTRA", "{}")))
    headers = {"Content-Type": "application/json", "User-Agent": "VoiceInk-eval/1.0"}
    if k:
        headers["Authorization"] = f"Bearer {k}"
    for attempt in range(6):
        req = urllib.request.Request(ENDPOINT, json.dumps(body).encode(), headers)
        try:
            t0 = time.time()
            r = json.load(urllib.request.urlopen(req, timeout=120))
            usage = r.get("usage", {})
            return {"output": r["choices"][0]["message"]["content"], "seconds": round(time.time() - t0, 2),
                    "prompt_tokens": usage.get("prompt_tokens"), "completion_tokens": usage.get("completion_tokens")}
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                time.sleep(2 ** attempt); continue
            raise
        except (TimeoutError, urllib.error.URLError):
            time.sleep(2 ** attempt); continue
    raise RuntimeError("retries exhausted")

def main():
    k = None if LOCAL else key()
    cases = json.load(open(f"{STATE}/{CASES}"))
    template = current_template()
    variants = json.load(open(os.environ.get("VARIANTS", f"{HERE}/variants.json")))
    jobs = [(c, v, i) for c in cases for v in variants for i in range(RUNS)]
    def do(job):
        c, v, i = job
        return {"case": c["id"], "variant": v, "run": i, **call(k, system_for(template, variants[v]), c["text"])}
    with ThreadPoolExecutor(int(os.environ.get("WORKERS", "4"))) as ex:
        results = list(ex.map(do, jobs))
    json.dump(results, open(f"{STATE}/{RESULTS}", "w"), indent=1)
    print(f"{len(results)} outputs -> {STATE}/{RESULTS}")

if __name__ == "__main__":
    main()
