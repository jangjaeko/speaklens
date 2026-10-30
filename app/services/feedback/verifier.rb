module Feedback
  # Checks Claude's labels against the actual transcript and counts habits in code (ADR 003).
  # Anything that points at someone else's sentence, or quotes text that isn't there, is dropped.
  class Verifier
    # sentences: the same array passed to Analyzer#analyze, each with :utterance_id, :speaker, :text.
    def initialize(sentences, result)
      @sentences = sentences
      @result = result
    end

    def corrections
      @result.corrections.filter_map do |correction|
        sentence = my_sentence(correction["sentence_id"])
        next unless sentence && sentence[:text].include?(correction["original"].to_s)
        next if correction["original"].strip.empty? || correction["original"] == correction["corrected"]
        next unless Correction.categories.key?(correction["category"])

        correction.slice("original", "corrected", "explanation", "category").merge("utterance_id" => sentence[:utterance_id])
      end
    end

    # {"like" => 3, "you know" => 2}. A phrase counts at most as often as it really appears in that sentence.
    def habit_stats
      @result.habit_occurrences
        .group_by { |occurrence| [ occurrence["sentence_id"], occurrence["phrase"].to_s.downcase.strip ] }
        .each_with_object(Hash.new(0)) do |((sentence_id, phrase), labels), counts|
          sentence = my_sentence(sentence_id)
          next if sentence.nil? || phrase.empty?

          actual = sentence[:text].downcase.scan(/\b#{Regexp.escape(phrase)}\b/).size
          counts[phrase] += [ labels.size, actual ].min if actual.positive?
        end
    end

    def suggestions
      @result.suggestions.map { |suggestion| suggestion.slice("phrase", "alternatives", "tip") }
    end

    def summary
      @result.summary
    end

    private
      def my_sentence(sentence_id)
        sentence = @sentences[sentence_id] if sentence_id.is_a?(Integer) && sentence_id >= 0
        sentence if sentence&.dig(:speaker) == "me"
      end
  end
end
