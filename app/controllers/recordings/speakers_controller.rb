# PATCH /recordings/:recording_id/speaker — the user picks which speaker they are.
class Recordings::SpeakersController < ApplicationController
  def update
    @recording = Current.user.recordings.find(params[:recording_id])
    speaker = Integer(params.expect(:speaker), exception: false)

    if @recording.select_speaker(speaker)
      AnalyzeRecordingJob.perform_later(@recording)
      redirect_to @recording, notice: "Got it. Analyzing your speech..."
    else
      redirect_to @recording, alert: "That speaker can't be selected."
    end
  end
end
