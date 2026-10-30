require "test_helper"

class RecordingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def build_recording(consent: true, file: "sample.wav", content_type: nil)
    recording = users(:one).recordings.new(consent: consent)
    recording.audio.attach(io: file_fixture(file).open, filename: file, content_type: content_type) if file
    recording
  end

  test "valid with consent and an audio file" do
    recording = build_recording

    assert recording.save
    assert_predicate recording, :uploaded?
    assert_not_nil recording.consent_confirmed_at
  end

  test "requires consent" do
    recording = build_recording(consent: false)

    assert_not recording.valid?
    assert_includes recording.errors.full_messages, "Consent is required. Let the other person know you're recording."
  end

  test "requires an audio file" do
    recording = build_recording(file: nil)

    assert_not recording.valid?
    assert_includes recording.errors[:audio], "must be attached"
  end

  test "rejects files that are not audio" do
    recording = build_recording(file: "not_audio.txt")

    assert_not recording.valid?
    assert_includes recording.errors[:audio], "must be an audio file"
  end

  test "rejects files over the size limit" do
    recording = build_recording
    recording.audio.blob.byte_size = Recording::MAX_AUDIO_SIZE + 1

    assert_not recording.valid?
    assert_includes recording.errors[:audio], "must be smaller than 25 MB"
  end

  test "privacy options default to on" do
    recording = build_recording

    assert recording.delete_audio_after_transcription?
    assert recording.discard_others_utterances?
  end

  test "tells open pages to refresh when it changes" do
    recording = recordings(:one)

    perform_enqueued_jobs do
      recording.transcribing!
    end

    assert_turbo_stream_broadcasts recording, count: 1
  end
end
