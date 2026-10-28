class RecordingsController < ApplicationController
  # GET /recordings
  def index
    @recordings = Current.user.recordings.order(created_at: :desc)
  end

  # GET /recordings/:id
  def show
    @recording = Current.user.recordings.find(params[:id])
  end

  # GET /recordings/new
  def new
    @recording = Current.user.recordings.new
  end

  # POST /recordings
  def create
    @recording = Current.user.recordings.new(recording_params)

    if @recording.save
      redirect_to @recording, notice: "Recording uploaded."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def recording_params
      params.expect(recording: [ :audio, :consent, :delete_audio_after_transcription, :discard_others_utterances ])
    end
end
