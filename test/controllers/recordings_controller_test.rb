require "test_helper"

class RecordingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "requires sign in" do
    sign_out
    get recordings_path
    assert_redirected_to new_session_path
  end

  test "index lists only my recordings" do
    get recordings_path

    assert_response :success
    assert_select "li a[href=?]", recording_path(recordings(:one))
    assert_select "li a[href=?]", recording_path(recordings(:two)), count: 0
  end

  test "new" do
    get new_recording_path
    assert_response :success
  end

  test "create uploads the audio and starts transcription" do
    assert_difference "Recording.count", 1 do
      post recordings_path, params: { recording: { audio: fixture_file_upload("sample.wav", "audio/wav"), consent: "1" } }
    end

    recording = Recording.last
    assert_redirected_to recording_path(recording)
    assert_equal users(:one), recording.user
    assert recording.audio.attached?
    assert_enqueued_with job: TranscribeRecordingJob, args: [ recording ]
  end

  test "create without consent re-renders the form" do
    assert_no_difference "Recording.count" do
      post recordings_path, params: { recording: { audio: fixture_file_upload("sample.wav", "audio/wav"), consent: "0" } }
    end

    assert_response :unprocessable_content
  end

  test "show" do
    get recording_path(recordings(:one))
    assert_response :success
  end

  test "show lists the transcript" do
    recordings(:one).utterances.create!(speaker: 1, text: "Hello there.", start_ms: 65_000, end_ms: 66_000)

    get recording_path(recordings(:one))

    assert_select "li", text: /Speaker B\s+1:05\s+Hello there\./
  end

  test "cannot see another user's recording" do
    get recording_path(recordings(:two))
    assert_response :not_found
  end

  test "show asks which speaker I am while awaiting a speaker" do
    recordings(:one).update!(status: :awaiting_speaker)

    get recording_path(recordings(:one))

    assert_select "#speaker_picker li", count: 2
    assert_select "#speaker_picker", text: /Tell me about yourself/
  end

  test "show marks my lines after I pick a speaker" do
    recordings(:one).update!(status: :completed, my_speaker: 1)

    get recording_path(recordings(:one))

    assert_select "#speaker_picker", count: 0
    assert_select "li", text: /Speaker B\s+You/
  end
end
