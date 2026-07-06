# frozen_string_literal: true

class AddActualPromptToImageResults < ActiveRecord::Migration[7.1]
  def change
    add_column :image_results, :actual_prompt, :text
  end
end
