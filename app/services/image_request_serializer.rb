# frozen_string_literal: true

class ImageRequestSerializer
  def self.serialize(request, routes: Rails.application.routes.url_helpers)
    new(request, routes: routes).as_json
  end

  def initialize(request, routes:)
    @request = request
    @routes = routes
  end

  def as_json
    {
      id: request.id,
      prompt: request.prompt,
      status: request.status,
      source: request.source,
      width: request.width,
      height: request.height,
      steps: request.steps,
      error_message: request.error_message,
      results: request.image_results.order(:id).map { |result| serialize_result(result) }
    }
  end

  private

  attr_reader :request, :routes

  def serialize_result(result)
    {
      id: result.id,
      checkpoint_name: result.checkpoint_name,
      status: result.status,
      error_message: result.error_message,
      actual_prompt: result.prompt_sent_to_ai,
      image_url: result.image_file ? routes.generated_image_path(result) : nil,
      regenerate_url: routes.regenerate_generated_image_path(result),
      width: result.generation_width,
      height: result.generation_height,
      steps: result.generation_steps,
      seed: result.seed,
      duration_sec: result.duration_sec
    }
  end
end
