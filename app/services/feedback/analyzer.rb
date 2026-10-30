module Feedback
  # Asks Claude to judge the user's speech: corrections, verbal habits, better expressions.
  # It only labels and suggests; Feedback::Verifier checks the labels and code does the counting (ADR 003).
  class Analyzer
    MODEL = "claude-opus-5-5"
    MAX_CORRECTIONS = 15

    Error = Class.new(StandardError)
    RetryableError = Class.new(Error) # Rate limits, overload, network, a malformed response
    PermanentError = Class.new(Error) # Bad request, bad key, a refusal: retrying won't help

    # sentence_id refers to the position in the sentences passed to #analyze.
    Result = Data.define(:summary, :corrections, :habit_occurrences, :suggestions)

    SYSTEM_PROMPT = <<~PROMPT
      You are an English speaking coach for a non-native speaker who works and interviews in
      English in Canada. You receive a transcript of one of their conversations as numbered
      sentences. Sentences marked "me" are the user's; sentences marked "other" are the other
      person's and are context only. Never correct or label "other" sentences.

      The transcript comes from speech-to-text, so it can contain recognition errors (for example
      "a little bit on lanes" where the speaker said "Ruby on Rails"). Don't correct words that
      look like recognition errors. Judge spoken English, not writing: contractions, short answers
      and casual phrasing are fine.

      Return:
      - summary: 2-4 sentences of feedback on their speaking style (clarity, structure, tone), written to the user as "you".
      - corrections: at most #{MAX_CORRECTIONS}, the most useful first. "original" must be copied exactly
        from that sentence (the shortest span that shows the problem); "corrected" is the fixed span.
        category is "grammar" for errors, "naturalness" for correct but unnatural phrasing, and
        "word_choice" for a vague or repeated word with a better option.
      - habit_occurrences: every place where the user uses a word or phrase as a verbal habit or filler
        ("like", "you know", "I mean", "actually", "basically", "kind of", or anything else they repeat
        out of habit). Only label uses that work as a filler in context: "I'm, like, really into it" is a
        habit, "I like Rails" is not. "phrase" must be copied exactly from the sentence, in lowercase.
        List the same phrase again for each time it occurs.
      - suggestions: up to 5 words or phrases the user overuses, each with 2-4 natural alternatives and
        a one-sentence tip. Empty if nothing stands out.
    PROMPT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[summary corrections habit_occurrences suggestions],
      properties: {
        summary: { type: "string" },
        corrections: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[sentence_id original corrected explanation category],
            properties: {
              sentence_id: { type: "integer" },
              original: { type: "string" },
              corrected: { type: "string" },
              explanation: { type: "string" },
              category: { type: "string", enum: %w[grammar naturalness word_choice] }
            }
          }
        },
        habit_occurrences: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[sentence_id phrase],
            properties: { sentence_id: { type: "integer" }, phrase: { type: "string" } }
          }
        },
        suggestions: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[phrase alternatives tip],
            properties: {
              phrase: { type: "string" },
              alternatives: { type: "array", items: { type: "string" } },
              tip: { type: "string" }
            }
          }
        }
      }
    }.freeze

    def initialize(client: nil)
      @client = client
    end

    # sentences: [{ speaker: "me" | "other", text: "..." }, ...] in the order they were spoken.
    def analyze(sentences)
      response = client.beta.messages.create(
        model: MODEL,
        max_tokens: 16_000,
        system_: SYSTEM_PROMPT,
        output_config: { effort: :medium, format_: { type: :json_schema, schema: SCHEMA } },
        # If a safety classifier declines, retry on a substitute model instead of failing.
        betas: [ "server-side-fallback-2026-07-01" ],
        fallbacks: :default,
        messages: [ { role: "user", content: transcript(sentences) } ]
      )

      case response.stop_reason
      when :refusal then raise PermanentError, "Claude declined to analyze this transcript"
      when :max_tokens then raise PermanentError, "Claude's response was cut off"
      end

      parse(response.content.find { |block| block.type == :text }&.text)
    rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError, Anthropic::Errors::APIConnectionError => error
      raise RetryableError, "Claude request failed: #{error.class}"
    rescue Anthropic::Errors::APIStatusError => error
      raise PermanentError, "Claude returned HTTP #{error.status}: #{error.type}"
    end

    private
      def client
        @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"].presence || Rails.application.credentials.dig(:anthropic, :api_key))
      end

      def transcript(sentences)
        lines = sentences.each_with_index.map { |sentence, index| "#{index} [#{sentence[:speaker]}] #{sentence[:text]}" }
        "Transcript:\n#{lines.join("\n")}"
      end

      # Structured outputs make the JSON valid, but treat anything unexpected as a bad response.
      def parse(text)
        json = JSON.parse(text.to_s)
        Result.new(
          summary: json.fetch("summary"),
          corrections: json.fetch("corrections"),
          habit_occurrences: json.fetch("habit_occurrences"),
          suggestions: json.fetch("suggestions")
        )
      rescue JSON::ParserError, KeyError
        raise RetryableError, "Claude returned a response that doesn't match the schema"
      end
  end
end
