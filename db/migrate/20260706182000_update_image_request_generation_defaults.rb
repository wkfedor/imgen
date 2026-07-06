# frozen_string_literal: true

class UpdateImageRequestGenerationDefaults < ActiveRecord::Migration[7.1]
  def change
    change_column_default :image_requests, :width, from: 1024, to: 768
    change_column_default :image_requests, :height, from: 1024, to: 1344
    change_column_default :image_requests, :steps, from: 24, to: 60
  end
end
