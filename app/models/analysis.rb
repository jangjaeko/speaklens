class Analysis < ApplicationRecord
  belongs_to :recording
  has_many :corrections, -> { order(:id) }, dependent: :delete_all, inverse_of: :analysis

  # Tracks the LLM step on its own: word stats are saved even if the LLM call fails.
  enum :status, { pending: "pending", completed: "completed", failed: "failed" }, validate: true

  # habit_stats is stored as {"like" => 3, "you know" => 2}; show the most frequent first.
  def habits_by_count
    habit_stats.sort_by { |phrase, count| [ -count, phrase ] }
  end
end
