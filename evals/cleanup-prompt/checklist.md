# Cleanup prompt checklist

Target: the most minimal layer-2 prompt (task instructions) that, inside VoiceInk's fixed system instructions, cleans dictation neutrally for any app. Pass or fail per output; an item that does not apply passes.

1. **Words kept**: nothing said is lost, added, or reworded. Normal tidying passes: dropping repeated words, adding "a" or "and", merging short sentences.
2. **Clear mishearings fixed**: fix a word the Dictionary or context makes clear. A word not in the Dictionary passes if left as heard.
3. **Guesses**: a guess at an unclear word or `<unk>` passes if a reader would agree it is what was meant; it fails if it changes the meaning or deletes the word.
4. **Spoken cues applied**: dictated punctuation, self-corrections (keep only the final wording), and numbers as digits.
5. **Voice kept**: greetings, sign-offs, informal abbreviations, and profanity stay.
6. **Not answered**: questions and requests stay as text; never answered or acted on.
7. **Obvious lists structured**: a spoken enumeration or run of standalone items becomes a `1.` or `- ` list; items mentioned in passing inside a sentence stay prose.
8. **Paragraphs**: a break between separate thoughts passes, even in a short message.
9. **Text only**: no preamble, quotes, tags, or labels.

Tyler's grade overrides this checklist where they disagree.
