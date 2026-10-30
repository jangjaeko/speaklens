# Runs after the user picks their speaker. Word stats and LLM corrections will be added here.
class AnalyzeRecordingJob < ApplicationJob
  queue_as :default

  def perform(recording)
    return unless recording.analyzing?

    # Privacy option: once analysis is done, keep only the user's own speech.
    recording.utterances.where.not(speaker: recording.my_speaker).delete_all if recording.discard_others_utterances?
    recording.completed!
  end
end
