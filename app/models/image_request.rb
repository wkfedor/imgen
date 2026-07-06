# frozen_string_literal: true

class ImageRequest < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  has_many :image_results, dependent: :destroy

  validates :prompt, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }

  def failed?
    status == "failed"
  end

  def refresh_status!
    statuses = image_results.pluck(:status)
    update!(status: statuses.all?("completed") ? "completed" : "failed", finished_at: Time.current)
  end
end
