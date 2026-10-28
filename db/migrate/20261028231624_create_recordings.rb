class CreateRecordings < ActiveRecord::Migration[8.1]
  def change
    create_table :recordings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "uploaded"
      t.string :error_message
      t.string :stt_request_id
      t.decimal :duration_seconds, precision: 8, scale: 2
      t.integer :my_speaker
      t.datetime :consent_confirmed_at, null: false
      t.boolean :delete_audio_after_transcription, null: false, default: true
      t.boolean :discard_others_utterances, null: false, default: true
      t.datetime :audio_deleted_at

      t.timestamps
    end

    add_index :recordings, [ :user_id, :created_at ]
  end
end
