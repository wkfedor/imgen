# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class ImageRequestsControllerTest < ActionDispatch::IntegrationTest
      test "create stores api source request and enqueues generation" do
        ComfyResultGenerationJob.jobs.clear

        post api_v1_image_requests_path, params: {
          prompt: "api prompt",
          models: ["model-a.safetensors"],
          width: 512,
          height: 768,
          steps: 12
        }, as: :json

        assert_response :created
        body = JSON.parse(response.body)
        request_record = ImageRequest.last
        assert_equal true, body.fetch("ok")
        assert_equal request_record.id, body.dig("data", "id")
        assert_equal "api", body.dig("data", "source")
        assert_equal "api", request_record.source
        assert_equal "api prompt", request_record.prompt
        assert_equal ["model-a.safetensors"], request_record.image_results.order(:id).pluck(:checkpoint_name)
        assert_equal 1, ComfyResultGenerationJob.jobs.size
        assert_equal "comfy_generation", ComfyResultGenerationJob.jobs.first["queue"]
      end

      test "statuses returns compact batch data" do
        first_request = ImageRequest.create!(prompt: "first", status: "running", source: "api")
        first_result = first_request.image_results.create!(checkpoint_name: "model-a.safetensors", status: "running")
        second_request = ImageRequest.create!(prompt: "second", status: "queued", source: "api")
        second_request.image_results.create!(checkpoint_name: "model-b.safetensors", status: "queued")

        get statuses_api_v1_image_requests_path(ids: "#{second_request.id},#{first_request.id}"), as: :json

        assert_response :success
        body = JSON.parse(response.body)
        assert_equal true, body.fetch("ok")
        assert_equal [second_request.id, first_request.id], body.dig("data", "requests").map { |request| request.fetch("id") }
        assert_equal first_result.id, body.dig("data", "requests", 1, "results", 0, "id")
      end

      test "show returns envelope with request data" do
        request_record = ImageRequest.create!(prompt: "prompt", source: "api")
        request_record.image_results.create!(checkpoint_name: "model-a.safetensors")

        get api_v1_image_request_path(request_record), as: :json

        assert_response :success
        body = JSON.parse(response.body)
        assert_equal true, body.fetch("ok")
        assert_equal request_record.id, body.dig("data", "id")
        assert_equal "api", body.dig("data", "source")
        assert_equal 1, body.dig("data", "results").size
      end

       test "retry delegates to shared behavior" do
         ComfyResultGenerationJob.jobs.clear
         request_record = ImageRequest.create!(prompt: "old", status: "failed", source: "api")
         result = request_record.image_results.create!(checkpoint_name: "model-a.safetensors", status: "failed", error_message: "bad")

        post retry_api_v1_image_request_path(request_record), params: { prompt: "new", width: 640, height: 640, steps: 20 }, as: :json

        assert_response :success
        assert_equal "queued", request_record.reload.status
        assert_equal "new", request_record.prompt
        assert_equal "queued", result.reload.status
        assert_equal "new", result.actual_prompt
         assert_equal 1, ComfyResultGenerationJob.jobs.size
         assert_equal "comfy_generation", ComfyResultGenerationJob.jobs.first["queue"]
       end

      test "destroy_all removes all requests through api" do
        first_request = ImageRequest.create!(prompt: "first", status: "completed", source: "api")
        second_request = ImageRequest.create!(prompt: "second", status: "completed", source: "api")
        first_request.image_results.create!(checkpoint_name: "model-a.safetensors", status: "completed")
        second_request.image_results.create!(checkpoint_name: "model-b.safetensors", status: "completed")

        delete destroy_all_api_v1_image_requests_path, as: :json

        assert_response :success
        body = JSON.parse(response.body)
        assert_equal true, body.fetch("ok")
        assert_equal 2, body.dig("data", "requests_deleted")
        assert_equal 0, ImageRequest.count
        assert_equal 0, ImageResult.count
      end
    end
  end
end
