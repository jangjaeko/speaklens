require "test_helper"

class AnalyzeRecordingJobTest < ActiveJob::TestCase
  # Stands in for Feedback::Analyzer so tests never call Claude.
  class FakeAnalyzer
    attr_reader :sentences

    def initialize(result: nil, raises: nil)
      @result, @raises = result, raises
    end

    def analyze(sentences)
      @sentences = sentences
      raise @raises if @raises
      @result
    end
  end

  setup do
    @recording = recordings(:one)
    @recording.update!(status: :analyzing, my_speaker: 1, discard_others_utterances: false)
  end

  def feedback
    Feedback::Analyzer::Result.new(
      summary: "Clear answer.",
      corrections: [ { "sentence_id" => 1, "original" => "I build", "corrected" => "I built", "explanation" => "Past tense.", "category" => "grammar" } ],
      habit_occurrences: [],
      suggestions: [ { "phrase" => "really", "alternatives" => [ "genuinely" ], "tip" => "Vary it." } ]
    )
  end

  def perform_with(analyzer)
    job = AnalyzeRecordingJob.new(@recording)
    job.analyzer = analyzer
    job.perform_now
    @recording.reload
  end

  test "saves word stats, verified corrections and feedback, then completes" do
    analyzer = FakeAnalyzer.new(result: feedback)
    perform_with analyzer

    analysis = @recording.analysis
    assert_predicate @recording, :completed?
    assert_predicate analysis, :completed?
    assert_equal 9, analysis.word_stats["total_words"]
    assert_equal "Clear answer.", analysis.summary
    assert_equal [ [ "I build", "I built", utterances(:my_answer) ] ], analysis.corrections.map { [ _1.original, _1.corrected, _1.utterance ] }
    assert_equal "really", analysis.suggestions.first["phrase"]
    assert_equal [ "other", "me" ], analyzer.sentences.pluck(:speaker)
  end

  test "discards the other person's speech afterwards when the user asked for it" do
    @recording.update!(discard_others_utterances: true)

    perform_with FakeAnalyzer.new(result: feedback)

    assert_equal [ utterances(:my_answer) ], @recording.utterances.to_a
  end

  test "keeps word stats and completes the recording when Claude fails" do
    assert_no_enqueued_jobs only: AnalyzeRecordingJob do
      perform_with FakeAnalyzer.new(raises: Feedback::Analyzer::PermanentError.new("refused"))
    end

    assert_predicate @recording, :completed?
    assert_predicate @recording.analysis, :failed?
    assert_equal 9, @recording.analysis.word_stats["total_words"]
  end

  test "retries when Claude is temporarily unavailable" do
    assert_enqueued_with(job: AnalyzeRecordingJob) do
      perform_with FakeAnalyzer.new(raises: Feedback::Analyzer::RetryableError.new("overloaded"))
    end

    assert_predicate @recording, :analyzing?
    assert_predicate @recording.analysis, :pending?
  end

  test "does nothing unless the recording is being analyzed" do
    @recording.update!(status: :completed)

    perform_with FakeAnalyzer.new(raises: RuntimeError.new("should not be called"))

    assert_nil @recording.analysis
  end
end
