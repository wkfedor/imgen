# frozen_string_literal: true

class ImageRequest < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze
  SOURCES = %w[web api].freeze

  has_many :image_results, dependent: :destroy

  validates :prompt, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 128, less_than_or_equal_to: 1536 }
  validates :steps, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 80 }

  scope :recent_first, -> { order(created_at: :desc) }

  before_validation :apply_generation_defaults

  def failed?
    status == "failed"
  end

  def api_source?
    source == "api"
  end

  def refresh_status!
    statuses = image_results.pluck(:status)
    next_status = if statuses.empty?
      "failed"
    elsif statuses.any?("running") || (statuses.any?("completed") && statuses.any?("queued"))
      "running"
    elsif statuses.any?("queued")
      "queued"
    elsif statuses.any?("failed")
      "failed"
    else
      "completed"
    end

    attrs = { status: next_status }
    attrs[:finished_at] = Time.current if %w[completed failed].include?(next_status)
    update!(attrs)
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
    self.width ||= 768
    self.height ||= 1344
    self.steps ||= 60
  end
end
