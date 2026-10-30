# Runs after the user picks their speaker: word stats in code, then Claude's feedback (ADR 003).
class AnalyzeRecordingJob < ApplicationJob
  queue_as :default

  # Rate limits, overload or a malformed response: try once more after a short wait.
  retry_on Feedback::Analyzer::RetryableError, wait: :polynomially_longer, attempts: 2 do |job, error|
    job.fail_analysis(error)
  end

  # A refusal, a bad request or a bad key: retrying won't help.
  discard_on Feedback::Analyzer::PermanentError do |job, error|
    job.fail_analysis(error)
  end

  attr_writer :analyzer

  def perform(recording)
    return unless recording.analyzing?

    sentences = recording.utterances.map do |utterance|
      { utterance_id: utterance.id, speaker: utterance.mine? ? "me" : "other", text: utterance.text }
    end

    # Saved before the LLM call, so the stats survive even if Claude fails.
    analysis = recording.analysis || recording.create_analysis!(
      word_stats: WordStats.new(sentences.select { |sentence| sentence[:speaker] == "me" }.pluck(:text)).to_h
    )

    verified = Feedback::Verifier.new(sentences, analyzer.analyze(sentences))

    Analysis.transaction do
      analysis.corrections.delete_all
      analysis.corrections.insert_all!(verified.corrections) if verified.corrections.any?
      analysis.update!(status: :completed, habit_stats: verified.habit_stats, suggestions: verified.suggestions, summary: verified.summary)
    end

    finish(recording)
  end

  def fail_analysis(error)
    Rails.logger.error("[AnalyzeRecordingJob] #{error.class}: #{error.message}")
    recording = arguments.first
    recording.analysis&.update!(status: :failed, error_message: "AI feedback isn't available for this recording. You can try again.")
    finish(recording)
  end

  private
    def analyzer
      @analyzer ||= Feedback::Analyzer.new
    end

    # Word stats are shown either way, so the recording is complete even if the LLM step failed.
    def finish(recording)
      # Privacy option: once analysis is done, keep only the user's own speech.
      recording.utterances.where.not(speaker: recording.my_speaker).delete_all if recording.discard_others_utterances?
      recording.completed!
    end
end
