class CreateAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :analyses do |t|
      t.references :recording, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "pending"
      t.jsonb :word_stats, null: false, default: {}
      t.jsonb :habit_stats, null: false, default: {}
      t.jsonb :suggestions, null: false, default: []
      t.text :summary
      t.string :error_message

      t.timestamps
    end
  end
end
