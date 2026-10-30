require "test_helper"

class Feedback::VerifierTest < ActiveSupport::TestCase
  setup do
    @sentences = [
      { utterance_id: 10, speaker: "other", text: "Do you, like, enjoy Rails?" },
      { utterance_id: 11, speaker: "me", text: "I'm, like, really into it, like, a lot." },
      { utterance_id: 12, speaker: "me", text: "I like Rails because it help me." }
    ]
  end

  def verify(corrections: [], habit_occurrences: [], suggestions: [])
    result = Feedback::Analyzer::Result.new(summary: "Good.", corrections:, habit_occurrences:, suggestions:)
    Feedback::Verifier.new(@sentences, result)
  end

  def correction(sentence_id, original, category: "grammar")
    { "sentence_id" => sentence_id, "original" => original, "corrected" => "it helps me", "explanation" => "Agreement.", "category" => category }
  end

  test "keeps corrections that quote the user's own sentence" do
    corrections = verify(corrections: [ correction(2, "it help me") ]).corrections

    assert_equal [ { "original" => "it help me", "corrected" => "it helps me", "explanation" => "Agreement.", "category" => "grammar", "utterance_id" => 12 } ], corrections
  end

  test "drops corrections on the other person's sentence, made-up quotes, bad ids and unknown categories" do
    verifier = verify(corrections: [
      correction(0, "Do you"),
      correction(2, "it helped me"),
      correction(9, "it help me"),
      correction(-1, "it help me"),
      correction(2, "it help me", category: "style")
    ])

    assert_empty verifier.corrections
  end

  test "counts each labeled habit, but never more often than it appears" do
    habits = verify(habit_occurrences: [
      { "sentence_id" => 1, "phrase" => "like" },
      { "sentence_id" => 1, "phrase" => "Like" },
      { "sentence_id" => 1, "phrase" => "like" }
    ]).habit_stats

    assert_equal({ "like" => 2 }, habits)
  end

  test "ignores habits in the other person's sentences or missing from the text" do
    habits = verify(habit_occurrences: [
      { "sentence_id" => 0, "phrase" => "like" },
      { "sentence_id" => 2, "phrase" => "you know" }
    ]).habit_stats

    assert_empty habits
  end

  test "matches whole words only" do
    habits = verify(habit_occurrences: [ { "sentence_id" => 1, "phrase" => "real" } ]).habit_stats

    assert_empty habits
  end
end
