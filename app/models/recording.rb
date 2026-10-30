class Recording < ApplicationRecord
  MAX_DURATION = 5.minutes
  MAX_AUDIO_SIZE = 25.megabytes
  # Chrome records audio/webm, Safari audio/mp4. Content sniffing can label either as video/*.
  ALLOWED_AUDIO_TYPES = %w[audio/webm audio/mp4 audio/mpeg audio/ogg audio/wav audio/x-wav video/webm video/mp4].freeze

  belongs_to :user
  has_one_attached :audio
  has_many :utterances, -> { order(:start_ms) }, dependent: :delete_all

  # After every change, tell open pages showing this recording to reload themselves.
  broadcasts_refreshes

  enum :status, {
    uploaded: "uploaded",
    transcribing: "transcribing",
    awaiting_speaker: "awaiting_speaker",
    analyzing: "analyzing",
    completed: "completed",
    failed: "failed"
  }, validate: true

  # Checkbox on the upload form. Not a column: we store when consent was given instead.
  attribute :consent, :boolean
  before_validation :record_consent_time, if: :consent

  validates :consent_confirmed_at, presence: { message: "is required. Let the other person know you're recording." }
  validate :audio_must_be_valid, on: :create

  private
    def record_consent_time
      self.consent_confirmed_at ||= Time.current
    end

    def audio_must_be_valid
      if !audio.attached?
        errors.add(:audio, "must be attached")
      elsif !audio.content_type.in?(ALLOWED_AUDIO_TYPES)
        errors.add(:audio, "must be an audio file")
      elsif audio.byte_size > MAX_AUDIO_SIZE
        errors.add(:audio, "must be smaller than #{MAX_AUDIO_SIZE / 1.megabyte} MB")
      end
    end
end
