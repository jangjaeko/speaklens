# Data Model

- **Status:** Agreed (2026-10-28), Analysis and Correction revised 2026-10-30 (ADR 003).

```mermaid
erDiagram
  User ||--o{ Session : has
  User ||--o{ Recording : has
  Recording ||--o{ Utterance : has
  Recording ||--o| Analysis : has
  Analysis ||--o{ Correction : has
  Utterance ||--o{ Correction : has
```

## Tables

### User
Created by Rails 8's authentication generator (`email_address`, `password_digest`) plus
its `Session` model.

### Recording

| Column | Type | Notes |
|---|---|---|
| `user_id` | references | |
| `audio` | Active Storage attachment | `has_one_attached :audio` (no column) |
| `status` | string, enum | `uploaded` / `transcribing` / `awaiting_speaker` / `analyzing` / `completed` / `failed` |
| `error_message` | string | Shown to the user when `failed` |
| `stt_request_id` | string | Deepgram request ID, for debugging |
| `duration_seconds` | decimal | From Deepgram's `metadata.duration`, not from the browser |
| `my_speaker` | integer, null | Set when the user picks "I am speaker A" |
| `consent_confirmed_at` | datetime, not null | Recording is not accepted without consent |
| `delete_audio_after_transcription` | boolean, default true | Privacy option |
| `discard_others_utterances` | boolean, default true | Privacy option |
| `audio_deleted_at` | datetime | |

### Utterance

| Column | Type | Notes |
|---|---|---|
| `recording_id` | references | |
| `speaker` | integer | Deepgram's speaker index (0, 1, …). Shown as "Speaker A", "B", … |
| `text` | text | |
| `start_ms`, `end_ms` | integer | |

Index: `(recording_id, start_ms)`.

### Analysis

One per recording. Filled by `AnalyzeRecordingJob` (see ADR 003 for who computes what).

| Column | Type | Notes |
|---|---|---|
| `recording_id` | references, unique | One analysis per recording |
| `status` | string, enum | `pending` / `completed` / `failed`: tracks the LLM step on its own |
| `word_stats` | jsonb | **Code.** Total and unique word counts, top words without stopwords |
| `habit_stats` | jsonb | **AI labels, code counts.** Verbal habits the model found in context, tallied in Ruby after validation |
| `suggestions` | jsonb | **AI.** Overused words or phrases with alternative expressions |
| `summary` | text | **AI.** Short feedback on speaking style |
| `error_message` | string | Why the LLM step failed |

### Correction

| Column | Type | Notes |
|---|---|---|
| `analysis_id` | references | |
| `utterance_id` | references | Must be one of the user's own utterances |
| `original` | text | Exact phrase from the utterance (validated before saving) |
| `corrected` | text | |
| `explanation` | text | |
| `category` | string | `grammar` / `naturalness` / `word_choice` |

Stored as rows (not jsonb) so the Phase 3 review feature can query them.

## Decisions made during review

- **No `Utterance.mine` column.** It would duplicate `Recording.my_speaker`, and the two
  could disagree after the user re-picks a speaker. "My utterances" is a scope that joins
  on `utterances.speaker = recordings.my_speaker`.
- **`speaker` is an integer**, matching Deepgram's response. Labels like "Speaker A" are a
  view concern.
- **`Analysis.status` is kept** even though `Recording.status` covers the overall flow.
  Word and filler stats are deterministic, but the LLM step can fail on its own; this lets
  us show stats with a "corrections failed" notice instead of failing the whole recording.
- **Status enums are string-backed** so rows are readable in `psql` and the order of
  values can change without a data migration.
- **No `language` column** for now: analysis is English-only (CLAUDE.md §5).
- **No column for the daily limit:** count today's recordings with
  `user.recordings.where(created_at: Time.current.all_day).count`.
- **`duration_seconds` comes from Deepgram**, because values sent by the browser can be
  tampered with. The 5-minute limit is enforced in the browser for UX and by file size on
  the server.
- **(2026-10-30) `filler_stats` became `habit_stats`, and `Correction.suggested_expression`
  was dropped.** Habits are now found by the LLM in context instead of a keyword list
  (ADR 003). For a naturalness fix, `corrected` already holds the more natural sentence,
  and alternatives for overused words live in `Analysis.suggestions`.
