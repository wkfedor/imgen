# frozen_string_literal: true

class AddGenerationSettingsToImageResults < ActiveRecord::Migration[7.1]
  def change
    add_column :image_results, :width, :integer
    add_column :image_results, :height, :integer
    add_column :image_results, :steps, :integer
  end
end
