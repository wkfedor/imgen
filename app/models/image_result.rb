# frozen_string_literal: true

class ImageResult < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  belongs_to :image_request
  validates :checkpoint_name, presence: true
  validates :status, inclusion: { in: STATUSES }

  def image_file
    return nil if path.blank?

    full_path = Pathname.new(path).expand_path
    storage_root = Rails.root.join("storage/generated").expand_path
    return full_path if full_path.file? && full_path.to_s.start_with?("#{storage_root}/")

    nil
  rescue StandardError
    nil
  end
end
