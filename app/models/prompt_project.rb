# frozen_string_literal: true

class PromptProject < ApplicationRecord
  STATUSES = %w[active archived].freeze

  belongs_to :active_prompt_revision, class_name: "PromptRevision", optional: true
  has_many :prompt_revisions, dependent: :destroy

  validates :title, :original_goal, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }

  def create_initial_revision!(prompt:, negative_prompt: nil)
    revision = prompt_revisions.create!(
      version_label: next_revision_label,
      prompt: prompt,
      negative_prompt: negative_prompt,
      change_summary: "Исходная версия промпта"
    )
    update!(active_prompt_revision: revision)
    revision
  end

  def next_revision_label
    (prompt_revisions.count + 1).to_s
  end
end
