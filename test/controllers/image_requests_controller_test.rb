# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class FakeModelClient
  def models
    ["sd_xl_base_1.0.safetensors", "LunerriaMixAnime_ILL_v3.safetensors"]
  end
end

class ImageRequestsControllerTest < ActionDispatch::IntegrationTest
  test "index renders discovered model checkboxes" do
    ComfyClient.stub(:new, FakeModelClient.new) do
      get image_requests_path
    end

    assert_response :success
    assert_includes response.body, "sd_xl_base_1.0.safetensors"
    assert_includes response.body, "LunerriaMixAnime_ILL_v3.safetensors"
  end

  test "create stores request results and enqueues sidekiq job" do
    ComfyGenerationJob.jobs.clear

    post image_requests_path, params: {
      prompt: "one prompt",
      models: ["sd_xl_base_1.0.safetensors", "LunerriaMixAnime_ILL_v3.safetensors"]
    }

    request_record = ImageRequest.last
    assert_redirected_to image_requests_path(anchor: "request-#{request_record.id}")
    assert_equal "one prompt", request_record.prompt
    assert_equal 2, request_record.image_results.count
    assert_equal ["sd_xl_base_1.0.safetensors", "LunerriaMixAnime_ILL_v3.safetensors"], request_record.image_results.order(:id).pluck(:checkpoint_name)
    assert_equal 1, ComfyGenerationJob.jobs.size
    assert_equal "imgen", ComfyGenerationJob.jobs.first["queue"]
  end
end
