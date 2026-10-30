# 003. The LLM judges, code counts

- **Status:** Accepted
- **Date:** 2026-10-30
- **Replaces:** CLAUDE.md §5-2 as first written ("statistics are counted in code, not by the LLM")

## Context

SpeakLens shows the user their verbal habits ("like", "you know", "I mean"…), corrects
grammar, and suggests more natural expressions.

The original plan counted habits with a keyword list in Ruby. That breaks on context:

| Sentence | Is "like" a habit? |
|---|---|
| "I'm, like, really into Rails." | Yes |
| "I like Rails." | No, it's a verb |
| "Like I said, it was hard." | Maybe; depends on how often it's used |

A fixed list also decides in advance what a habit is, but people repeat different phrases.

We considered a punctuation heuristic (count "like" only next to a comma, since Deepgram's
`smart_format` tends to add one). It handles the first two rows, not the third, and fails
silently when punctuation is off.

On the other hand, LLMs are poor at counting: the same transcript can come back with "like ×4"
one time and "like ×5" the next, and the model can quote a phrase that isn't in the text.

## Decision

Split the work by what each side is good at.

| Task | Who |
|---|---|
| Is this occurrence a verbal habit? Which habits does this person have? | **LLM** |
| Grammar and naturalness corrections | **LLM** |
| Alternative expressions for overused words | **LLM** |
| Short speaking-style summary | **LLM** |
| Checking that every quoted phrase really exists in that sentence | **Code** |
| Tallying habit occurrences | **Code** |
| Word frequency (top words, totals) | **Code** |

- One LLM call per recording. The prompt contains the whole transcript as numbered
  sentences: the user's sentences to analyze, and the other speaker's for context only.
- The response must follow a fixed JSON schema (structured output). Each habit occurrence and
  each correction points at a sentence ID and quotes an exact phrase.
- Ruby drops anything that points at a sentence that isn't the user's, or quotes text that
  isn't in that sentence, then counts what's left.
- No vector database or retrieval: a 5-minute recording is about 1,000 tokens and fits in a
  single prompt, and the model needs the full conversation for context.

## Consequences

- Habit counts are accurate for the labels we store and reproducible from them. They still
  depend on the model's judgement, and re-running the analysis may label a borderline case
  differently. We store the result rather than re-running it.
- Word frequency stays free and deterministic.
- Each analysis costs one LLM call, so the daily limit per user (CLAUDE.md §8) matters.
- If the LLM call fails, word stats are still shown and the analysis is marked failed on
  its own (`Analysis.status`), instead of failing the whole recording.
