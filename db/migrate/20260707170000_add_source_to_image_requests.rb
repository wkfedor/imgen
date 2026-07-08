# frozen_string_literal: true

class AddSourceToImageRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :image_requests, :source, :string, null: false, default: "web"
    add_index :image_requests, :source
  end
end
