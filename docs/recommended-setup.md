# Recommended setup

The setup I use every day. Set it up in the app's Modes; each Mode has its own transcription model, language, and cleanup model and prompt.

| Mode | When | Transcription | Cleanup |
|---|---|---|---|
| Offline (default) | everywhere else | Parakeet Ultra (local), English | none |
| Enhancement | chat apps and sites: Slack, WhatsApp, Telegram, Signal, Messages, and their web versions | Parakeet Ultra (local), English | Cerebras, `qwen-3.8-27b`, the Default TS prompt below |

- Use Parakeet Ultra alone for anything that doesn't need custom terms or perfect formatting. It runs on-device and is the fastest path.
- Add Qwen 3.8 27B through Cerebras when you need custom terms and clean formatting. Cerebras serves it fast enough that cleanup adds little delay. It needs a Cerebras API key, added in the AI Models section.
- Keep the enhancement timeout short (3 seconds) so a slow response falls back to the raw transcript.
- Add your names and jargon to the Dictionary; the cleanup model uses them.

Change a model only if the new one is faster at the same accuracy. Winning an accuracy benchmark alone isn't enough.

## Default TS prompt

Create a custom prompt named "Default TS" with system instructions on, and paste this:

```
<TASK>
Clean <TRANSCRIPT> into polished, readable, general-purpose text.
</TASK>

<RULES>
- Preserve dictated greetings, sign-offs, headings, and informal abbreviations. Do not add any that were not spoken.
- Preserve profanity as spoken.
- Convert dictated punctuation to their respective symbols.
</RULES>

<EXAMPLES>
Input: For the invoice folder, we need first the printed map second two markers and third the spare batteries before Saturday Please include the small change in your reply, since the rest of the arrangements are already set.
Output:
For the invoice folder, we need the following before Saturday:

1. The printed map
2. Two markers
3. The spare batteries

Please include the small change in your reply, since the rest of the arrangements are already set.
</EXAMPLES>
```
