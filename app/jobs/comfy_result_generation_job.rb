# frozen_string_literal: true

class ComfyResultGenerationJob
  include Sidekiq::Job

  sidekiq_options queue: :imgen, retry: false

  def perform(image_result_id)
    result = ImageResult.includes(:image_request).find(image_result_id)
    request = result.image_request
    prompt = result.prompt_sent_to_ai
    width = result.generation_width
    height = result.generation_height
    steps = result.generation_steps
    request.update!(status: "running", started_at: Time.current, error_message: nil)
    result.update!(status: "running", error_message: nil, actual_prompt: prompt, width: width, height: height, steps: steps)

    generated = ComfyClient.new.generate(
      prompt: prompt,
      model: result.checkpoint_name,
      result_id: result.id,
      width: width,
      height: height,
      steps: steps
    )

    result.update!(
      status: "completed",
      prompt_id: generated.fetch(:prompt_id),
      seed: generated.fetch(:seed),
      filename: generated.fetch(:filename),
      path: generated.fetch(:path),
      bytes: generated.fetch(:bytes),
      duration_sec: generated.fetch(:duration_sec),
      remote_filename: generated[:remote_filename],
      remote_subfolder: generated[:remote_subfolder],
      remote_type: generated[:remote_type]
    )
  rescue StandardError => e
    result&.update!(status: "failed", error_message: e.message)
  ensure
    request&.refresh_status!
  end
end
