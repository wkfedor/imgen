# frozen_string_literal: true

class RenamePromptRunModelName < ActiveRecord::Migration[7.1]
  def change
    rename_column :prompt_runs, :model_name, :checkpoint_name
  end
end
