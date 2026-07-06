# frozen_string_literal: true

require "test_helper"

class ImageRequestTest < ActiveSupport::TestCase
  test "refresh_status marks completed when all results completed" do
    request = ImageRequest.create!(prompt: "prompt")
    request.image_results.create!(checkpoint_name: "a.safetensors", status: "completed")
    request.image_results.create!(checkpoint_name: "b.safetensors", status: "completed")

    request.refresh_status!

    assert_equal "completed", request.reload.status
    assert request.finished_at.present?
  end

  test "refresh_status marks failed when any result failed" do
    request = ImageRequest.create!(prompt: "prompt")
    request.image_results.create!(checkpoint_name: "a.safetensors", status: "completed")
    request.image_results.create!(checkpoint_name: "b.safetensors", status: "failed")

    request.refresh_status!

    assert_equal "failed", request.reload.status
  end
end
