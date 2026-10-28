# SpeakLens

Record a conversation, keep only your own speech, and see your most-used words, filler
habits, and grammar corrections for spoken English.

**Live demo:** https://speaklens-vvnb.onrender.com (work in progress)

## Stack

Rails 8.1 · PostgreSQL · Hotwire (Turbo + Stimulus) · Active Storage · Solid Queue ·
Deepgram Nova-3 (speech-to-text + diarization) · Claude API (corrections) · Render

## Design decisions

- [ADR 001 — Deepgram Nova-3 for STT and diarization](docs/decisions/001-stt-provider.md)
- [ADR 002 — Host on Render](docs/decisions/002-hosting.md)
- [Data model](docs/data-model.md)

## Development

```sh
bin/setup   # install gems, prepare the database, start the dev server
bin/rails test
```
