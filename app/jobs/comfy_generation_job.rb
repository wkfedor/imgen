# frozen_string_literal: true

class ComfyGenerationJob
  include Sidekiq::Job

  sidekiq_options queue: :imgen, retry: false

  def perform(image_request_id)
    request = ImageRequest.find(image_request_id)
    request.update!(status: "queued", started_at: nil, finished_at: nil, error_message: nil)

    request.image_results.order(:id).find_each do |result|
      ComfyResultGenerationJob.perform_async(result.id)
    end
  rescue StandardError => e
    request&.update!(status: "failed", error_message: e.message, finished_at: Time.current)
    raise
  end
end
