# frozen_string_literal: true

module Api
  module V1
    class ImageRequestsController < BaseController
      def index
        requests = ImageRequest.includes(:image_results).recent_first.limit(limit)
        render_success(requests.map { |request| serialize(request) })
      end

      def show
        render_success(serialize(ImageRequest.includes(:image_results).find(params[:id])))
      end

      def statuses
        requests = ImageRequest.includes(:image_results).where(id: status_ids)
        by_id = requests.index_by(&:id)

        render_success({
          requests: status_ids.filter_map { |id| by_id[id] }.map { |request| ImageRequestStatusSerializer.serialize(request) }
        })
      end

      def create
        request = ImageRequests::Create.call(params: image_request_params, source: "api")
        render_success(serialize(request), status: :created)
      end

      def retry
        request = ImageRequests::Retry.call(request: ImageRequest.includes(:image_results).find(params[:id]), params: image_request_params)
        render_success(serialize(request))
      end

       def destroy
         request = ImageRequest.includes(:image_results).find(params[:id])
         deleted = request.destroy_with_images!
         render_success({ id: request.id, deleted: deleted })
       end

      def destroy_all
        render_success(ImageRequests::DestroyAll.call)
      end

       def models
         render_success({ models: ComfyClient.new.models })
      rescue StandardError => e
        render_error(e.message, status: :bad_gateway)
      end

      private

      def image_request_params
        params.permit(:prompt, :width, :height, :steps, models: [])
      end

      def limit
        GenerationParams.bounded_integer(params[:limit], default: 100, min: 1, max: 100)
      end

      def status_ids
        params[:ids].to_s.split(",").filter_map do |id|
          Integer(id, exception: false)
        end.uniq.first(100)
      end

      def serialize(request)
        ImageRequestSerializer.serialize(request)
      end
    end
  end
end
