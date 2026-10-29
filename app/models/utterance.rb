class Utterance < ApplicationRecord
  belongs_to :recording

  validates :speaker, :text, :start_ms, :end_ms, presence: true

  # Deepgram numbers speakers 0, 1, 2... Show them as A, B, C...
  def speaker_name
    "Speaker #{(65 + speaker).chr}"
  end
end
