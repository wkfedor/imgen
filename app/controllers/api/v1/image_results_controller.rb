# frozen_string_literal: true

module Api
  module V1
    class ImageResultsController < BaseController
      def regenerate
        result = ImageResults::Regenerate.call(result: ImageResult.includes(:image_request).find(params[:id]), params: image_result_params)
        render_success(ImageRequestSerializer.serialize(result.image_request))
      end

      def destroy_image
        result = ImageResult.find(params[:id])
        deleted = result.delete_image_files!
        render_success({ id: result.id, image_request_id: result.image_request_id, deleted: deleted })
      end

      private

      def image_result_params
        params.permit(:prompt, :width, :height, :steps)
      end
    end
  end
end
