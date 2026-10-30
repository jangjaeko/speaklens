require "test_helper"

class TranscribeRecordingJobTest < ActiveJob::TestCase
  # Stands in for Transcription::Client so tests never reach Deepgram.
  class FakeClient
    def initialize(result: nil, raises: nil)
      @result, @raises = result, raises
    end

    def transcribe(_io, content_type:)
      raise @raises if @raises
      @result
    end
  end

  setup do
    @recording = users(:one).recordings.new(consent: true, delete_audio_after_transcription: false)
    @recording.audio.attach(io: file_fixture("sample.wav").open, filename: "sample.wav")
    @recording.save!
  end

  def deepgram_result
    Transcription::Client.parse(JSON.parse(file_fixture("deepgram/single_speaker.json").read))
  end

  def perform_with(client)
    job = TranscribeRecordingJob.new(@recording)
    job.client = client
    job.perform_now
    @recording.reload
  end

  test "saves utterances and waits for the user to pick a speaker" do
    perform_with FakeClient.new(result: deepgram_result)

    assert_predicate @recording, :awaiting_speaker?
    assert_equal 8, @recording.utterances.count
    assert_equal "So I've been working as a software developer for about three years.", @recording.utterances.first.text
    assert_equal "01a189da-16f7-7e13-adc9-f004eb3c3a17", @recording.stt_request_id
    assert_in_delta 60.42, @recording.duration_seconds
    assert @recording.audio.attached?
  end

  test "deletes the audio when the user asked for it" do
    @recording.update!(delete_audio_after_transcription: true)

    perform_with FakeClient.new(result: deepgram_result)

    assert_not @recording.audio.attached?
    assert_not_nil @recording.audio_deleted_at
  end

  test "does nothing for a recording that was already transcribed" do
    @recording.update!(status: :awaiting_speaker)

    perform_with FakeClient.new(raises: RuntimeError.new("should not be called"))

    assert_predicate @recording, :awaiting_speaker?
  end

  test "fails when no speech was detected" do
    perform_with FakeClient.new(result: deepgram_result.with(utterances: []))

    assert_predicate @recording, :failed?
    assert_equal "No speech was detected in this recording.", @recording.error_message
  end

  test "accepts long recordings from users with a higher limit" do
    users(:one).update!(max_recording_minutes: 60)

    perform_with FakeClient.new(result: deepgram_result.with(duration_seconds: 45 * 60.0))

    assert_predicate @recording, :awaiting_speaker?
  end

  test "fails recordings longer than the limit" do
    perform_with FakeClient.new(result: deepgram_result.with(duration_seconds: 400.0))

    assert_predicate @recording, :failed?
    assert_equal 0, @recording.utterances.count
  end

  test "retries on a retryable error" do
    assert_enqueued_with(job: TranscribeRecordingJob) do
      perform_with FakeClient.new(raises: Transcription::Client::RetryableError.new("HTTP 503"))
    end

    assert_predicate @recording, :transcribing?
  end

  test "fails without retrying on a permanent error" do
    assert_no_enqueued_jobs only: TranscribeRecordingJob do
      perform_with FakeClient.new(raises: Transcription::Client::PermanentError.new("HTTP 400"))
    end

    assert_predicate @recording, :failed?
    assert_equal "We couldn't transcribe this recording. Please try again.", @recording.error_message
  end
end
