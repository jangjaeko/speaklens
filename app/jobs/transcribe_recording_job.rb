class TranscribeRecordingJob < ApplicationJob
  queue_as :default

  # Network trouble or a Deepgram outage: try again a few times, waiting longer each time.
  retry_on Transcription::Client::RetryableError, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.fail_recording(error)
  end

  # Bad audio or a config problem: retrying won't help.
  discard_on Transcription::Client::PermanentError do |job, error|
    job.fail_recording(error)
  end

  attr_writer :client

  def perform(recording)
    # The job may run twice (retries, a re-enqueue); only start from a fresh upload.
    return unless recording.uploaded? || recording.transcribing?

    recording.transcribing!
    result = recording.audio.open do |file|
      client.transcribe(file, content_type: recording.audio.content_type)
    end

    if result.utterances.empty?
      recording.update!(status: :failed, error_message: "No speech was detected in this recording.")
    elsif result.duration_seconds > Recording::MAX_DURATION + 10.seconds
      recording.update!(status: :failed, error_message: "Recordings can be at most #{Recording::MAX_DURATION.in_minutes.to_i} minutes long.")
    else
      save_transcript(recording, result)
    end

    delete_audio(recording) if recording.delete_audio_after_transcription?
  end

  def fail_recording(error)
    Rails.logger.error("[TranscribeRecordingJob] #{error.class}: #{error.message}")
    arguments.first.update!(status: :failed, error_message: "We couldn't transcribe this recording. Please try again.")
  end

  private
    def client
      @client ||= Transcription::Client.new
    end

    def save_transcript(recording, result)
      Recording.transaction do
        recording.utterances.delete_all
        recording.utterances.insert_all!(result.utterances.map(&:to_h))
        recording.update!(status: :awaiting_speaker, stt_request_id: result.request_id, duration_seconds: result.duration_seconds)
      end
    end

    def delete_audio(recording)
      recording.audio.purge
      recording.update!(audio_deleted_at: Time.current)
    end
end
