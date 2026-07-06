# frozen_string_literal: true

class PromptRevision < ApplicationRecord
  belongs_to :prompt_project
  belongs_to :parent_revision, class_name: "PromptRevision", optional: true
  belongs_to :created_from_feedback, class_name: "PromptFeedback", optional: true
  has_many :child_revisions, class_name: "PromptRevision", foreign_key: :parent_revision_id, dependent: :nullify, inverse_of: :parent_revision
  has_many :prompt_runs, dependent: :destroy

  validates :version_label, :prompt, presence: true

  scope :oldest_first, -> { order(:created_at, :id) }

  def next_child_label
    prompt_project.next_revision_label
  end
end
