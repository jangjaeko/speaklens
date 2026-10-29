class CreateUtterances < ActiveRecord::Migration[8.1]
  def change
    create_table :utterances do |t|
      t.references :recording, null: false, foreign_key: true, index: false
      t.integer :speaker, null: false
      t.text :text, null: false
      t.integer :start_ms, null: false
      t.integer :end_ms, null: false

      t.timestamps
    end

    add_index :utterances, [ :recording_id, :start_ms ]
  end
end
