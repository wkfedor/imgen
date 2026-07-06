# frozen_string_literal: true

class ComfyGenerationJob
  include Sidekiq::Job

  sidekiq_options queue: :imgen, retry: false

  def perform(image_request_id)
    request = ImageRequest.find(image_request_id)
    request.update!(status: "running", started_at: Time.current, error_message: nil)
    client = ComfyClient.new

    request.image_results.order(:id).find_each do |result|
      result.update!(status: "running", error_message: nil, actual_prompt: request.prompt, width: request.width, height: request.height, steps: request.steps)
      begin
        generated = client.generate(
          prompt: request.prompt,
          model: result.checkpoint_name,
          result_id: result.id,
          width: request.width,
          height: request.height,
          steps: request.steps
        )
        result.update!(status: "completed", prompt_id: generated.fetch(:prompt_id), seed: generated.fetch(:seed), filename: generated.fetch(:filename), path: generated.fetch(:path), bytes: generated.fetch(:bytes), duration_sec: generated.fetch(:duration_sec), remote_filename: generated[:remote_filename], remote_subfolder: generated[:remote_subfolder], remote_type: generated[:remote_type])
      rescue StandardError => e
        result.update!(status: "failed", error_message: e.message)
      end
    end

    request.refresh_status!
  rescue StandardError => e
    request&.update!(status: "failed", error_message: e.message, finished_at: Time.current)
    raise
  end
end
