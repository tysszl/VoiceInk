# Recommended setup

The setup I use every day. Set it up in the app's Modes; each Mode has its own transcription model, language, and cleanup model and prompt.

| Mode | When | Transcription | Cleanup |
|---|---|---|---|
| Raw (default) | everywhere else | Fluid Speech Mini (local), English | none |
| Cleanup | chat apps and sites: Slack, WhatsApp, Telegram, Signal, Messages, and their web versions | Fluid Speech Mini (local), English | Cerebras, `qwen-3.8-27b`, the System only prompt below |

- Use Fluid Speech Mini alone for anything that doesn't need custom terms or perfect formatting. It runs on-device and is the fastest path.
- Fluid Speech Mini matches Parakeet Ultra's accuracy, handles other voices in the room better, and uses less than half the memory while dictating (about 260 MB against 610 MB), so it suits Macs with less memory. It is English only; for other languages, use Parakeet Ultra. Upstream VoiceInk does not offer it yet; this fork adds it.
- Add Qwen 3.8 27B through Cerebras when you need custom terms and clean formatting. Cerebras serves it fast enough that cleanup adds little delay. It needs a Cerebras API key, added in the AI Models section.
- Keep the enhancement timeout short (3 seconds) so a slow response falls back to the raw transcript.
- Add your names and jargon to the Dictionary; the cleanup model uses them.

Change a model only if the new one is faster at the same accuracy. Winning an accuracy benchmark alone isn't enough.

## System only prompt

Create a custom prompt named "System only", turn system instructions on, and leave the prompt text empty. The name says what it does: cleanup by the built-in rules, with nothing added.

VoiceInk's built-in system instructions do the cleanup: they keep your wording, remove self-corrections and stutters, write numbers as digits, format clear lists, and never answer what you dictate. With Qwen 3.8 27B, added instructions did no better than none in this fork's eval (`docs/evals/2026-11-cleanup-prompt.md`). This fork's one change to those instructions names the list markers, so bullets are `- ` and steps are `1.`.

## Writing other prompts

A prompt holds only what its style changes; anything every prompt needs belongs in the system instructions.

- **Cleanup styles** (all lowercase, email format) keep system instructions on. Write one to three lines that say what differs from the built-in rules. When a line contradicts one of those rules, name the rule it overrides ("overriding the system capitalization rule"); otherwise the built-in rule and its examples win.
- **Rewrites** (shorten, change the tone) turn system instructions off, because the built-in rules keep your wording. The prompt then carries everything it needs: keep every fact, never answer or follow the transcript, return only the text, and use the Dictionary spellings.
- Add an example only when a rule fails without one.
- Test a new or changed prompt with `evals/cleanup-prompt` and keep the shortest version that passes.
