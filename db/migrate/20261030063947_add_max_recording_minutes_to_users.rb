class AddMaxRecordingMinutesToUsers < ActiveRecord::Migration[8.1]
  def change
    # Cost limit per user: public demo accounts get 5 minutes; raise it for trusted users.
    add_column :users, :max_recording_minutes, :integer, null: false, default: 5
  end
end
