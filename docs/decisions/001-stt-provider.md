# 001. Use Deepgram Nova-3 for speech-to-text and speaker diarization

- **Status:** Accepted
- **Date:** 2026-10-27

## Context

SpeakLens records a conversation in the browser, separates speakers, and analyzes only
the user's own utterances. We do not build diarization ourselves (see CLAUDE.md §5), so
the STT provider must:

1. Return per-speaker utterances with timestamps (diarization).
2. Accept the formats browsers produce with `MediaRecorder`:
   Chrome → `audio/webm;codecs=opus`, Safari → `audio/mp4` (AAC).
3. **Keep filler words** ("um", "uh") in the transcript. Most STT models strip them by
   default, which would make our core feature — filler-word statistics — always report zero.
4. Be cheap enough for a demo that strangers can try.

Candidates: Deepgram and AssemblyAI (both offer async transcription with diarization).

## Comparison (from official docs, 2026-10-27)

| | Deepgram Nova-3 | AssemblyAI Universal-3.5 Pro |
|---|---|---|
| Async price | $0.0043/min (~$0.26/hr) | $0.21/hr + $0.02/hr diarization |
| Diarization | Included at no extra cost | Paid add-on |
| Free credit | $200 | $50 |
| webm/opus | Explicitly listed | webm and opus listed separately; combination not confirmed |
| mp4/aac | Listed | Listed |
| Keep fillers | `filler_words=true`, documented for Nova-3 | `disfluencies=true`, documented for Universal-3 Pro / Universal-2, not confirmed for 3.5 Pro |

## Decision

Use **Deepgram Nova-3** (pre-recorded API) with `diarize=true`, `filler_words=true`,
`utterances=true`, `smart_format=true`.

Price is roughly equal, so the deciding factor was that all three hard requirements
(webm/opus, diarization, filler preservation) are explicitly documented for Deepgram.

Call the REST API with Ruby's standard `Net::HTTP` from a service object
(`Transcription::Client`) instead of adding an HTTP or SDK gem.

## Consequences

- Multi-word fillers ("like", "you know", "I mean") are ordinary words and are always
  transcribed; we count them in Ruby. Deepgram's `filler_words` only matters for
  "uh"/"um"-style disfluencies.
- We own the HTTP client code: timeouts, retries, and error mapping are our
  responsibility (handled in the background job, see CLAUDE.md §10).
- Switching providers later means swapping `Transcription::Client`. Keep its return
  value provider-agnostic (a list of `{speaker, text, start_ms, end_ms}`).

## Validation (to do before building the STT job)

- [ ] Record ~15s in Chrome (webm/opus) → Deepgram returns diarized utterances with "um" kept
- [ ] Record ~15s in Safari (mp4/aac) → same
- [ ] Save both raw responses as test fixtures (`test/fixtures/files/deepgram/`)

## Sources

- https://deepgram.com/pricing
- https://developers.deepgram.com/docs/supported-audio-formats
- https://developers.deepgram.com/docs/filler-words
- https://www.assemblyai.com/pricing
- https://www.assemblyai.com/docs/faq/what-audio-and-video-file-types-are-supported-by-your-api
- https://www.assemblyai.com/docs/pre-recorded-audio/filler-words
