# frozen_string_literal: true

class ImageResult < ApplicationRecord
  STATUSES = %w[queued running completed failed deleted].freeze

  belongs_to :image_request
  validates :checkpoint_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :width, :height, numericality: { only_integer: true, greater_than_or_equal_to: 128, less_than_or_equal_to: 1536 }, allow_nil: true
  validates :steps, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 80 }, allow_nil: true

  def prompt_sent_to_ai
    actual_prompt.presence || image_request.prompt
  end

  def generation_width
    width || image_request.width
  end

  def generation_height
    height || image_request.height
  end

  def generation_steps
    steps || image_request.steps
  end

  def image_file
    return nil if path.blank?

    full_path = Pathname.new(path).expand_path
    storage_root = Rails.root.join("storage/generated").expand_path
    return full_path if full_path.file? && full_path.to_s.start_with?("#{storage_root}/")

    nil
  rescue StandardError
    nil
  end

  def delete_image_files!
    local_deleted = delete_local_image
    remote_deleted = delete_remote_image

    update!(
      status: "deleted",
      prompt_id: nil,
      seed: nil,
      filename: nil,
      path: nil,
      bytes: nil,
      duration_sec: nil,
      error_message: nil,
      remote_filename: nil,
      remote_subfolder: nil,
      remote_type: nil
    )

    { local_deleted: local_deleted, remote_deleted: remote_deleted }
  end

  def reset_for_regeneration!(prompt:, width:, height:, steps:)
    delete_local_image
    delete_remote_image

    update!(
      status: "queued",
      prompt_id: nil,
      seed: nil,
      filename: nil,
      path: nil,
      bytes: nil,
      duration_sec: nil,
      error_message: nil,
      actual_prompt: prompt,
      width: width,
      height: height,
      steps: steps,
      remote_filename: nil,
      remote_subfolder: nil,
      remote_type: nil
    )
  end

  private

  def delete_local_image
    file = image_file
    return false unless file

    File.delete(file)
    true
  rescue Errno::ENOENT
    false
  end

  def delete_remote_image
    inferred_filename = remote_filename.presence || inferred_remote_filename
    prefix = remote_delete_prefix
    return false if inferred_filename.blank? && prefix.blank?

    ComfyClient.new.delete_remote_image(filename: inferred_filename, subfolder: remote_subfolder, type: remote_type, prefix: prefix)
  end

  def remote_delete_prefix
    return nil if filename.blank?

    marker = "_000"
    index = filename.index(marker)
    return nil unless index

    filename[0...index]
  end

  def inferred_remote_filename
    return nil if filename.blank? || prompt_id.blank?

    ext = File.extname(filename)
    suffix = "_#{prompt_id}#{ext}"
    return nil unless filename.end_with?(suffix)

    "#{filename.delete_suffix(suffix)}#{ext}"
  end
end
