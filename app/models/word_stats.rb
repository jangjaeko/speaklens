# Counts words in plain Ruby: free, exact and reproducible (ADR 003).
class WordStats
  TOP_LIMIT = 10

  # Words too common to say anything about someone's speaking style.
  STOPWORDS = %w[
    a about after all also am an and any are as at be because been but by can could did do does
    for from get got had has have he her him his how i i'm i've i'd i'll if in into is it it's its
    just me my no not of on one or our out so some than that that's the their them then there they
    this to up us was we we're were what when which who will with would yeah yes you you're your
  ].to_set.freeze

  def initialize(texts)
    @words = texts.join(" ").downcase.scan(/[a-z]+(?:'[a-z]+)?/)
  end

  def to_h
    {
      "total_words" => @words.size,
      "unique_words" => @words.uniq.size,
      "top_words" => @words.reject { |word| STOPWORDS.include?(word) }.tally
                           .sort_by { |word, count| [ -count, word ] }.first(TOP_LIMIT)
    }
  end
end
