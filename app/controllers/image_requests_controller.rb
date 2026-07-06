# frozen_string_literal: true

class ImageRequestsController < ApplicationController
  def index
    @models = ComfyClient.new.models
    @image_requests = ImageRequest.includes(:image_results).recent_first.limit(100)
  rescue StandardError => e
    @models = []
    @model_error = e.message
    @image_requests = ImageRequest.includes(:image_results).recent_first.limit(100)
  end

  def show
    render json: serialize_request(ImageRequest.includes(:image_results).find(params[:id]))
  end

  def create
    prompt = params[:prompt].to_s.strip
    models = Array(params[:models]).map(&:to_s).map(&:strip).reject(&:blank?)
    raise "Промпт пустой" if prompt.blank?
    raise "Выберите хотя бы одну модель" if models.blank?

    request = ImageRequest.create!(prompt: prompt)
    models.each { |model| request.image_results.create!(checkpoint_name: model) }
    ComfyGenerationJob.perform_async(request.id)

    redirect_to image_requests_path(anchor: "request-#{request.id}"), notice: "Задача ##{request.id} добавлена в очередь"
  rescue StandardError => e
    redirect_to image_requests_path, alert: e.message
  end

  def retry
    request = ImageRequest.find(params[:id])
    request.update!(status: "queued", error_message: nil, started_at: nil, finished_at: nil)
    request.image_results.update_all(
      status: "queued",
      error_message: nil,
      prompt_id: nil,
      seed: nil,
      filename: nil,
      path: nil,
      bytes: nil,
      duration_sec: nil,
      updated_at: Time.current
    )
    ComfyGenerationJob.perform_async(request.id)

    redirect_to image_requests_path(anchor: "request-#{request.id}"), notice: "Задача ##{request.id} повторно добавлена в очередь"
  end

  def models
    render json: { models: ComfyClient.new.models }
  rescue StandardError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def image
    result = ImageResult.find(params[:id])
    file = result.image_file
    raise ActiveRecord::RecordNotFound unless file

    send_file file, type: "image/png", disposition: "inline"
  end

  private

  def serialize_request(request)
    {
      id: request.id,
      prompt: request.prompt,
      status: request.status,
      error_message: request.error_message,
      results: request.image_results.order(:id).map do |result|
        {
          id: result.id,
          checkpoint_name: result.checkpoint_name,
          status: result.status,
          error_message: result.error_message,
          image_url: result.image_file ? generated_image_path(result) : nil,
          seed: result.seed,
          duration_sec: result.duration_sec
        }
      end
    }
  end
end
