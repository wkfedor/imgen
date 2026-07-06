class CreateImageResults < ActiveRecord::Migration[7.1]
  def change
    create_table :image_results do |t|
      t.references :image_request, null: false, foreign_key: true
      t.string :model_name, null: false
      t.string :status, null: false, default: "queued"
      t.string :prompt_id
      t.integer :seed
      t.string :filename
      t.string :path
      t.integer :bytes
      t.float :duration_sec
      t.text :error_message

      t.timestamps
    end

    add_index :image_results, :status
    add_index :image_results, :model_name
  end
end
