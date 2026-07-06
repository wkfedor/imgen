# frozen_string_literal: true

class PromptRun < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  belongs_to :prompt_revision
  belongs_to :image_result, optional: true
  has_many :prompt_feedbacks, dependent: :destroy

  validates :checkpoint_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 128, less_than_or_equal_to: 1536 }
  validates :steps, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 80 }

  scope :recent_first, -> { order(created_at: :desc) }

  def image_file
    return image_result.image_file if image_result&.image_file
    return nil if image_path.blank?

    path = Pathname.new(image_path).expand_path
    root = Rails.root.join("storage/generated").expand_path
    return path if path.file? && path.to_s.start_with?("#{root}/")

    nil
  end
end
