# frozen_string_literal: true

class AddRemoteFileToImageResults < ActiveRecord::Migration[7.1]
  def change
    add_column :image_results, :remote_filename, :string
    add_column :image_results, :remote_subfolder, :string
    add_column :image_results, :remote_type, :string
  end
end
