# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class FakeModelClient
  def models
    ["sd_xl_base_1.0.safetensors", "LunerriaMixAnime_ILL_v3.safetensors"]
  end
end

class ImageRequestsControllerTest < ActionDispatch::IntegrationTest
  test "index renders model list placeholder without blocking on comfy" do
    get image_requests_path

    assert_response :success
    assert_includes response.body, 'data-autoload="true"'
    assert_includes response.body, "Модели загрузятся отдельным запросом"
    assert_not_includes response.body, "sd_xl_base_1.0.safetensors"
    assert_not_includes response.body, "LunerriaMixAnime_ILL_v3.safetensors"
  end

  test "create stores request results and enqueues one job per result" do
    ComfyResultGenerationJob.jobs.clear

    post image_requests_path, params: {
      prompt: "one prompt",
      models: ["sd_xl_base_1.0.safetensors", "LunerriaMixAnime_ILL_v3.safetensors"]
    }

    request_record = ImageRequest.last
    assert_redirected_to image_requests_path(anchor: "request-#{request_record.id}")
    assert_equal "one prompt", request_record.prompt
    assert_equal "web", request_record.source
    assert_equal 2, request_record.image_results.count
    assert_equal ["sd_xl_base_1.0.safetensors", "LunerriaMixAnime_ILL_v3.safetensors"], request_record.image_results.order(:id).pluck(:checkpoint_name)
    assert_equal 2, ComfyResultGenerationJob.jobs.size
    assert_equal ["comfy_generation", "comfy_generation"], ComfyResultGenerationJob.jobs.map { |job| job["queue"] }
  end

  test "destroy_result_image deletes generated image files" do
    request_record = ImageRequest.create!(prompt: "prompt", status: "completed")
    result = request_record.image_results.create!(checkpoint_name: "a.safetensors", status: "completed")

    delete destroy_generated_image_path(result)

    assert_redirected_to image_requests_path(anchor: "request-#{request_record.id}")
    assert_match "удалена", flash[:notice]
    assert_equal "deleted", result.reload.status
  end

   test "destroy removes request and its result records" do
     request_record = ImageRequest.create!(prompt: "prompt", status: "completed")
     result = request_record.image_results.create!(checkpoint_name: "a.safetensors", status: "completed")

    delete image_request_path(request_record)

    assert_redirected_to image_requests_path
    assert_match "Промпт", flash[:notice]
     assert_raises(ActiveRecord::RecordNotFound) { request_record.reload }
     assert_raises(ActiveRecord::RecordNotFound) { result.reload }
   end

  test "destroy_all removes all requests and result records" do
    first_request = ImageRequest.create!(prompt: "first", status: "completed")
    first_result = first_request.image_results.create!(checkpoint_name: "a.safetensors", status: "completed")
    second_request = ImageRequest.create!(prompt: "second", status: "completed")
    second_result = second_request.image_results.create!(checkpoint_name: "b.safetensors", status: "completed")

    delete destroy_all_image_requests_path

    assert_redirected_to image_requests_path
    assert_match "Удалены все промпты", flash[:notice]
    assert_raises(ActiveRecord::RecordNotFound) { first_request.reload }
    assert_raises(ActiveRecord::RecordNotFound) { second_request.reload }
    assert_raises(ActiveRecord::RecordNotFound) { first_result.reload }
    assert_raises(ActiveRecord::RecordNotFound) { second_result.reload }
  end

   test "index marks api-created requests" do
     ImageRequest.create!(prompt: "api prompt", source: "api")

    get image_requests_path

    assert_response :success
    assert_includes response.body, "source-badge"
    assert_includes response.body, "api"
  end

  test "index renders compact request rows without result cards" do
    request_record = ImageRequest.create!(prompt: "prompt", status: "completed")
    request_record.image_results.create!(checkpoint_name: "a.safetensors", status: "completed")

    get image_requests_path

    assert_response :success
    assert_includes response.body, "Показать картинки"
    assert_includes response.body, "детали загрузятся отдельно"
    assert_not_includes response.body, "result-card status-completed"
  end
end
