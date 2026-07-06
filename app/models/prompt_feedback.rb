# frozen_string_literal: true

class PromptFeedback < ApplicationRecord
  belongs_to :prompt_run
  belongs_to :next_prompt_revision, class_name: "PromptRevision", optional: true

  validates :prompt_run, presence: true
end
