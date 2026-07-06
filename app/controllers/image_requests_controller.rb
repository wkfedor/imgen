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
    width = bounded_integer(params[:width], default: 768, min: 128, max: 1536)
    height = bounded_integer(params[:height], default: 1344, min: 128, max: 1536)
    steps = bounded_integer(params[:steps], default: 60, min: 1, max: 80)
    raise "Промпт пустой" if prompt.blank?
    raise "Выберите хотя бы одну модель" if models.blank?

    request = ImageRequest.create!(prompt: prompt, width: width, height: height, steps: steps)
    models.each { |model| request.image_results.create!(checkpoint_name: model) }
    ComfyGenerationJob.perform_async(request.id)

    redirect_to image_requests_path(anchor: "request-#{request.id}"), notice: "Задача ##{request.id} добавлена в очередь"
  rescue StandardError => e
    redirect_to image_requests_path, alert: e.message
  end

  def retry
    request = ImageRequest.find(params[:id])
    prompt = params[:prompt].to_s.presence || request.prompt
    width = bounded_integer(params[:width], default: request.width, min: 128, max: 1536)
    height = bounded_integer(params[:height], default: request.height, min: 128, max: 1536)
    steps = bounded_integer(params[:steps], default: request.steps, min: 1, max: 80)
    request.update!(prompt: prompt, width: width, height: height, steps: steps, status: "queued", error_message: nil, started_at: nil, finished_at: nil)
    request.image_results.update_all(
      status: "queued",
      error_message: nil,
      prompt_id: nil,
      seed: nil,
      filename: nil,
      path: nil,
      bytes: nil,
      duration_sec: nil,
      actual_prompt: prompt,
      width: width,
      height: height,
      steps: steps,
      remote_filename: nil,
      remote_subfolder: nil,
      remote_type: nil,
      updated_at: Time.current
    )
    ComfyGenerationJob.perform_async(request.id)

    redirect_to image_requests_path(anchor: "request-#{request.id}"), notice: "Задача ##{request.id} повторно добавлена в очередь"
  end

  def destroy
    request = ImageRequest.includes(:image_results).find(params[:id])
    deleted = request.destroy_with_images!

    redirect_to image_requests_path, notice: "Промпт ##{request.id} удалён: локальных картинок=#{deleted[:local_deleted]}, серверных=#{deleted[:remote_deleted]}"
  rescue StandardError => e
    redirect_to image_requests_path, alert: "Не удалось удалить промпт: #{e.message}"
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

  def destroy_result_image
    result = ImageResult.find(params[:id])
    deleted = result.delete_image_files!

    redirect_to image_requests_path(anchor: "request-#{result.image_request_id}"), notice: "Картинка ##{result.id} удалена: локально=#{deleted[:local_deleted]}, сервер=#{deleted[:remote_deleted]}"
  rescue StandardError => e
    redirect_to image_requests_path, alert: "Не удалось удалить картинку: #{e.message}"
  end

  def regenerate_result_image
    result = ImageResult.includes(:image_request).find(params[:id])
    prompt = params[:prompt].to_s.presence || result.prompt_sent_to_ai
    width = bounded_integer(params[:width], default: result.generation_width, min: 128, max: 1536)
    height = bounded_integer(params[:height], default: result.generation_height, min: 128, max: 1536)
    steps = bounded_integer(params[:steps], default: result.generation_steps, min: 1, max: 80)
    result.reset_for_regeneration!(prompt: prompt, width: width, height: height, steps: steps)
    result.image_request.update!(status: "queued", error_message: nil, finished_at: nil)
    ComfyResultGenerationJob.perform_async(result.id)

    redirect_to image_requests_path(anchor: "request-#{result.image_request_id}"), notice: "Картинка ##{result.id} повторно добавлена в очередь"
  rescue StandardError => e
    redirect_to image_requests_path, alert: "Не удалось перегенерить картинку: #{e.message}"
  end

  private

  def serialize_request(request)
    {
      id: request.id,
      prompt: request.prompt,
      status: request.status,
      width: request.width,
      height: request.height,
      steps: request.steps,
      error_message: request.error_message,
      results: request.image_results.order(:id).map do |result|
        {
          id: result.id,
          checkpoint_name: result.checkpoint_name,
          status: result.status,
          error_message: result.error_message,
          actual_prompt: result.prompt_sent_to_ai,
          image_url: result.image_file ? generated_image_path(result) : nil,
          regenerate_url: regenerate_generated_image_path(result),
          width: result.generation_width,
          height: result.generation_height,
          steps: result.generation_steps,
          seed: result.seed,
          duration_sec: result.duration_sec
        }
      end
    }
  end

  def bounded_integer(value, default:, min:, max:)
    parsed = Integer(value.presence || default)
    [[parsed, min].max, max].min
  rescue ArgumentError, TypeError
    default
  end
end
