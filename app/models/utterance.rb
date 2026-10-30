class Utterance < ApplicationRecord
  belongs_to :recording

  validates :speaker, :text, :start_ms, :end_ms, presence: true

  # My utterances across all recordings (the speaker each recording's owner picked).
  scope :mine, -> { joins(:recording).where("utterances.speaker = recordings.my_speaker") }

  def mine?
    speaker == recording.my_speaker
  end

  # Deepgram numbers speakers 0, 1, 2... Show them as A, B, C...
  def speaker_name
    "Speaker #{(65 + speaker).chr}"
  end
end
