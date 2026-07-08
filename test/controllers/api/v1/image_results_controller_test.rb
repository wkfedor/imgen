# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class ImageResultsControllerTest < ActionDispatch::IntegrationTest
      test "regenerate queues one result through shared behavior" do
        ComfyResultGenerationJob.jobs.clear
        request_record = ImageRequest.create!(prompt: "prompt", status: "completed", source: "api")
        result = request_record.image_results.create!(checkpoint_name: "model-a.safetensors", status: "failed", actual_prompt: "old")

        post regenerate_api_v1_image_result_path(result), params: { prompt: "new", width: 512, height: 512, steps: 10 }, as: :json

        assert_response :success
        assert_equal "queued", request_record.reload.status
        assert_equal "queued", result.reload.status
        assert_equal "new", result.actual_prompt
        assert_equal 1, ComfyResultGenerationJob.jobs.size
      end

      test "destroy image marks result deleted" do
        request_record = ImageRequest.create!(prompt: "prompt", status: "completed", source: "api")
        result = request_record.image_results.create!(checkpoint_name: "model-a.safetensors", status: "completed")

        delete destroy_image_api_v1_image_result_path(result), as: :json

        assert_response :success
        body = JSON.parse(response.body)
        assert_equal true, body.fetch("ok")
        assert_equal "deleted", result.reload.status
      end
    end
  end
end
