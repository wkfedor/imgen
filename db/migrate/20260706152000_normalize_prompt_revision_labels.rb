# frozen_string_literal: true

class NormalizePromptRevisionLabels < ActiveRecord::Migration[7.1]
  def up
    PromptProject.find_each do |project|
      project.prompt_revisions.order(:created_at, :id).each.with_index(1) do |revision, index|
        revision.update_columns(version_label: index.to_s)
      end
    end
  end

  def down
    PromptProject.find_each do |project|
      project.prompt_revisions.order(:created_at, :id).each.with_index(1) do |revision, index|
        revision.update_columns(version_label: "v#{index}")
      end
    end
  end
end
