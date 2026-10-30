require "test_helper"

class AnalyzeRecordingJobTest < ActiveJob::TestCase
  setup do
    @recording = recordings(:one)
    @recording.update!(status: :analyzing, my_speaker: 1)
  end

  test "completes the recording" do
    AnalyzeRecordingJob.perform_now(@recording)

    assert_predicate @recording.reload, :completed?
  end

  test "discards the other person's speech when the user asked for it" do
    @recording.update!(discard_others_utterances: true)

    AnalyzeRecordingJob.perform_now(@recording)

    assert_equal [ utterances(:my_answer) ], @recording.utterances.to_a
  end

  test "keeps everyone's speech otherwise" do
    @recording.update!(discard_others_utterances: false)

    AnalyzeRecordingJob.perform_now(@recording)

    assert_equal 2, @recording.utterances.count
  end

  test "does nothing unless the recording is being analyzed" do
    @recording.update!(status: :completed, discard_others_utterances: true)

    AnalyzeRecordingJob.perform_now(@recording)

    assert_equal 2, @recording.utterances.count
  end
end
