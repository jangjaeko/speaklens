# POST /recordings/:recording_id/analysis — run (or re-run) AI feedback on a finished recording.
class Recordings::AnalysesController < ApplicationController
  def create
    @recording = Current.user.recordings.find(params[:recording_id])

    if @recording.restart_analysis
      AnalyzeRecordingJob.perform_later(@recording)
      redirect_to @recording, notice: "Analyzing your speech..."
    else
      redirect_to @recording, alert: "This recording can't be analyzed right now."
    end
  end
end
