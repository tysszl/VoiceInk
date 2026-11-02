# Cleanup prompt eval, November 2026

**Verdict:** with system instructions on, Qwen 3.8 27B on Cerebras needs no cleanup prompt. The default prompt is now empty and named "System only" (formerly Default TS). The one rule worth adding, the list markers, went into the system instructions (`AIPrompts.swift`), so every prompt gets it.

## How it was tested

- 55 cases: 14 real dictations (one held out) and 41 written to test one rule each: self-corrections, dictated punctuation and line breaks, numbers, contact details, lists and non-lists, requests that must not be answered, a prompt injection, slang and profanity, greetings and sign-offs, fillers, Dictionary terms, code and file names, a longer email, an agent prompt, homophones, and `<unk>` tokens.
- 3 runs per prompt per case, with VoiceInk's production request (temperature 0.3, reasoning off, the real Dictionary). Since the last round, `run.py` builds the system instructions from `AIPrompts.swift`.
- Graded against `evals/cleanup-prompt/checklist.md`: blind by an AI grader given Tyler's rulings on four outputs, plus per-case expected results for the written cases.

## Results

| Round | Compared | Finding |
|---|---|---|
| 1–2 | Default TS, Minimal TS, task line only, empty | Empty and Minimal TS tied (1 bad output in 66 each); Default TS 2. Every failure was a one-off guess at an unclear word, seen under several prompts. |
| Targeted | same, 32 written cases | All prompts passed every case on every run. Habits seen: `*` bullets with three spaces, semicolons, sign-off placement varying. Tyler kept semicolons and sign-offs as they are. |
| Bullets in the prompt | `Use "- " for bullets.` and two variants | Removed `*` bullets but turned numbered steps into bullets (up to 3 of 3 runs) and wrote "two kids" as "2 kids". |
| Both markers in the prompt | `Number ordered lists with "1." and bullet unordered ones with "- ".` | Lists fixed (12/12 numbered, 9/9 dashed, 15/15 prose kept); small numbers became digits 3 of 3. |
| Both markers in the system instructions, empty prompt | the shipped configuration | Lists fixed the same; "two kids" kept 2 of 3; no other changes. Confirmed again from source. |

Request time was about 0.3 s for every prompt, so prompt length does not affect speed.

## Gaps

- Misheard words not in the Dictionary (Cerebras, Qwen, MacBook) stay as heard; add them to the Dictionary.
- One-off guesses at unclear words (`outport` → `output`, `back book` → `backup`) remain at about 1 in 60 outputs under every prompt.
