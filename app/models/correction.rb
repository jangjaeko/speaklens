class Correction < ApplicationRecord
  belongs_to :analysis
  belongs_to :utterance

  enum :category, { grammar: "grammar", naturalness: "naturalness", word_choice: "word_choice" }, validate: true

  validates :original, :corrected, :explanation, presence: true
end
