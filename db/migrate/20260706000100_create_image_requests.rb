class CreateImageRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :image_requests do |t|
      t.text :prompt, null: false
      t.string :status, null: false, default: "queued"
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :image_requests, :status
    add_index :image_requests, :created_at
  end
end
