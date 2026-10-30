require "test_helper"

class Recordings::AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @recording = recordings(:one)
    @recording.update!(status: :completed, my_speaker: 1)
  end

  test "starts AI feedback for a finished recording without one" do
    post recording_analysis_path(@recording)

    assert_redirected_to recording_path(@recording)
    assert_predicate @recording.reload, :analyzing?
    assert_enqueued_with job: AnalyzeRecordingJob, args: [ @recording ]
  end

  test "retries after a failed analysis" do
    @recording.create_analysis!(status: :failed)

    post recording_analysis_path(@recording)

    assert_predicate @recording.reload, :analyzing?
    assert_nil @recording.analysis
  end

  test "won't re-run a successful analysis" do
    @recording.create_analysis!(status: :completed)

    post recording_analysis_path(@recording)

    assert_equal "This recording can't be analyzed right now.", flash[:alert]
    assert_no_enqueued_jobs only: AnalyzeRecordingJob
  end

  test "cannot analyze another user's recording" do
    recordings(:two).update!(status: :completed, my_speaker: 0)

    post recording_analysis_path(recordings(:two))

    assert_response :not_found
  end
end
