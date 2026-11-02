# Cleanup prompt eval

Tests VoiceInk's cleanup: the system instructions in `VoiceInk/Core/Enhancement/AIPrompts.swift` plus a prompt's text inside `<TASK_INSTRUCTIONS>`, graded against `checklist.md`. Default TS is empty, so the system instructions are what this mostly measures.

- `variants.json`: generic prompts under test. Personal prompts (your styles and retired defaults) stay in the state folder below; pass one with `VARIANTS=<file>`.
- `run.py`: sends each case to Cerebras `qwen-3.8-27b` exactly as VoiceInk does (temperature 0.3, reasoning off, system instructions built from `AIPrompts.swift`, and the Dictionary from a stored request), 3 runs per variant by default. It reads VoiceInk's Cerebras key from the login keychain.
- Cases, the system template, and results stay local in `~/.local/state/evals/voiceink/cleanup-prompt/`, because they are real dictations. Case `r13696` is held out.

Re-run after an upstream merge that touches `AIPrompts.swift`, a change to the cleanup model, or a new prompt: `python3 run.py 3`, then grade the outputs blind against `checklist.md`. `VARIANTS=<file>` swaps the prompt set and `TEMPLATE=<file>` uses a stored system message whole.
