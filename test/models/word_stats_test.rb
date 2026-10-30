require "test_helper"

class WordStatsTest < ActiveSupport::TestCase
  test "counts total and unique words, ignoring case and punctuation" do
    stats = WordStats.new([ "I really, really like Rails.", "Rails is great!" ]).to_h

    assert_equal 8, stats["total_words"]
    assert_equal 6, stats["unique_words"]
  end

  test "top words skip stopwords and are sorted by count, then alphabetically" do
    stats = WordStats.new([ "I think the project was really fun.", "Really, the project helped me think." ]).to_h

    assert_equal [ [ "project", 2 ], [ "really", 2 ], [ "think", 2 ], [ "fun", 1 ], [ "helped", 1 ] ], stats["top_words"]
  end

  test "keeps contractions as one word" do
    stats = WordStats.new([ "I'm sure it's fine, don't worry." ]).to_h

    assert_includes stats["top_words"].to_h.keys, "don't"
  end

  test "handles no text" do
    assert_equal({ "total_words" => 0, "unique_words" => 0, "top_words" => [] }, WordStats.new([]).to_h)
  end
end
