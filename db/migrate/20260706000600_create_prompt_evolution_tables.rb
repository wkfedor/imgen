# frozen_string_literal: true

class CreatePromptEvolutionTables < ActiveRecord::Migration[7.1]
  def change
    create_table :prompt_projects do |t|
      t.string :title, null: false
      t.text :original_goal, null: false
      t.text :acceptance_criteria
      t.string :status, null: false, default: "active"
      t.integer :active_prompt_revision_id

      t.timestamps
    end

    create_table :prompt_revisions do |t|
      t.references :prompt_project, null: false, foreign_key: true
      t.references :parent_revision, foreign_key: { to_table: :prompt_revisions }
      t.string :version_label, null: false
      t.text :prompt, null: false
      t.text :negative_prompt
      t.text :change_summary
      t.integer :created_from_feedback_id

      t.timestamps
    end

    create_table :prompt_runs do |t|
      t.references :prompt_revision, null: false, foreign_key: true
      t.references :image_result, foreign_key: true
      t.string :model_name, null: false
      t.integer :width, null: false, default: 384
      t.integer :height, null: false, default: 384
      t.integer :steps, null: false, default: 18
      t.integer :seed
      t.string :status, null: false, default: "queued"
      t.string :image_path
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    create_table :prompt_feedbacks do |t|
      t.references :prompt_run, null: false, foreign_key: true
      t.text :positives
      t.text :negatives
      t.text :keep
      t.text :remove
      t.text :next_direction
      t.text :ai_evaluation
      t.text :user_evaluation
      t.boolean :selected_for_continuation, null: false, default: false
      t.references :next_prompt_revision, foreign_key: { to_table: :prompt_revisions }

      t.timestamps
    end

    add_foreign_key :prompt_projects, :prompt_revisions, column: :active_prompt_revision_id
    add_foreign_key :prompt_revisions, :prompt_feedbacks, column: :created_from_feedback_id
  end
end
