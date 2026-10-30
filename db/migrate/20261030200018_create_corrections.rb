class CreateCorrections < ActiveRecord::Migration[8.1]
  def change
    create_table :corrections do |t|
      t.references :analysis, null: false, foreign_key: { on_delete: :cascade }
      t.references :utterance, null: false, foreign_key: { on_delete: :cascade }
      t.text :original, null: false
      t.text :corrected, null: false
      t.text :explanation, null: false
      t.string :category, null: false

      t.timestamps
    end
  end
end
