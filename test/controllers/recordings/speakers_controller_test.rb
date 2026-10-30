require "test_helper"

class Recordings::SpeakersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @recording = recordings(:one)
    @recording.update!(status: :awaiting_speaker)
  end

  test "picking a speaker starts analysis" do
    patch recording_speaker_path(@recording), params: { speaker: 1 }

    assert_redirected_to recording_path(@recording)
    assert_equal 1, @recording.reload.my_speaker
    assert_predicate @recording, :analyzing?
    assert_enqueued_with job: AnalyzeRecordingJob, args: [ @recording ]
  end

  test "a speaker who isn't in the transcript is rejected" do
    patch recording_speaker_path(@recording), params: { speaker: "abc" }

    assert_redirected_to recording_path(@recording)
    assert_equal "That speaker can't be selected.", flash[:alert]
    assert_nil @recording.reload.my_speaker
    assert_no_enqueued_jobs only: AnalyzeRecordingJob
  end

  test "cannot pick a speaker on another user's recording" do
    recordings(:two).update!(status: :awaiting_speaker)

    patch recording_speaker_path(recordings(:two)), params: { speaker: 0 }

    assert_response :not_found
  end
end
