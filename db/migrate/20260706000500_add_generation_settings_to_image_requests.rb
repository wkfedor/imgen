# frozen_string_literal: true

class AddGenerationSettingsToImageRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :image_requests, :width, :integer, null: false, default: 1024
    add_column :image_requests, :height, :integer, null: false, default: 1024
    add_column :image_requests, :steps, :integer, null: false, default: 24
  end
end
