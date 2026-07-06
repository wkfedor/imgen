# frozen_string_literal: true

class ImageRequest < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  has_many :image_results, dependent: :destroy

  validates :prompt, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 128, less_than_or_equal_to: 1536 }
  validates :steps, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 80 }

  scope :recent_first, -> { order(created_at: :desc) }

  before_validation :apply_generation_defaults

  def failed?
    status == "failed"
  end

  def refresh_status!
    statuses = image_results.pluck(:status)
    update!(status: statuses.all?("completed") ? "completed" : "failed", finished_at: Time.current)
  end

  def destroy_with_images!
    deleted = { local_deleted: 0, remote_deleted: 0 }

    image_results.find_each do |result|
      result_deleted = result.delete_image_files!
      deleted[:local_deleted] += 1 if result_deleted[:local_deleted]
      deleted[:remote_deleted] += 1 if result_deleted[:remote_deleted]
    end

    destroy!
    deleted
  end

  private

  def apply_generation_defaults
    self.width ||= 1024
    self.height ||= 1024
    self.steps ||= 24
  end
end
