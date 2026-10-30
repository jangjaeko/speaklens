require "test_helper"

class UtteranceTest < ActiveSupport::TestCase
  test "speaker names are letters" do
    assert_equal "Speaker A", utterances(:interviewer_question).speaker_name
    assert_equal "Speaker B", utterances(:my_answer).speaker_name
  end

  test "mine only includes the speaker the user picked" do
    recordings(:one).update!(my_speaker: 1)

    assert_equal [ utterances(:my_answer) ], Utterance.mine.to_a
    assert utterances(:my_answer).mine?
    assert_not utterances(:interviewer_question).mine?
  end

  test "nothing is mine before a speaker is picked" do
    assert_empty Utterance.mine
  end
end
