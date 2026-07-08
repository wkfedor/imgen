# frozen_string_literal: true

class ImageRequestsController < ApplicationController
  def index
    @models = []
    @image_requests = ImageRequest.recent_first.limit(100)
  rescue StandardError => e
    @models = []
    @model_error = e.message
    @image_requests = ImageRequest.recent_first.limit(100)
  end

  def show
    render json: ImageRequestSerializer.serialize(ImageRequest.includes(:image_results).find(params[:id]))
  end

  def create
    request = ImageRequests::Create.call(params: params, source: "web")

    redirect_to image_requests_path(anchor: "request-#{request.id}"), notice: "Задача ##{request.id} добавлена в очередь"
  rescue StandardError => e
    redirect_to image_requests_path, alert: e.message
  end

  def retry
    request = ImageRequests::Retry.call(request: ImageRequest.find(params[:id]), params: params)

    redirect_to image_requests_path(anchor: "request-#{request.id}"), notice: "Задача ##{request.id} повторно добавлена в очередь"
  end

   def destroy
     request = ImageRequest.includes(:image_results).find(params[:id])
     deleted = request.destroy_with_images!

     redirect_to image_requests_path, notice: "Промпт ##{request.id} удалён: локальных картинок=#{deleted[:local_deleted]}, серверных=#{deleted[:remote_deleted]}"
   rescue StandardError => e
     redirect_to image_requests_path, alert: "Не удалось удалить промпт: #{e.message}"
   end

  def destroy_all
    deleted = ImageRequests::DestroyAll.call

    redirect_to image_requests_path, notice: "Удалены все промпты: промптов=#{deleted[:requests_deleted]}, локальных картинок=#{deleted[:local_deleted]}, серверных=#{deleted[:remote_deleted]}"
  rescue StandardError => e
    redirect_to image_requests_path, alert: "Не удалось удалить все промпты: #{e.message}"
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
    result = ImageResults::Regenerate.call(result: ImageResult.includes(:image_request).find(params[:id]), params: params)

    redirect_to image_requests_path(anchor: "request-#{result.image_request_id}"), notice: "Картинка ##{result.id} повторно добавлена в очередь"
  rescue StandardError => e
    redirect_to image_requests_path, alert: "Не удалось перегенерить картинку: #{e.message}"
  end

  private
end
