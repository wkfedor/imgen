# frozen_string_literal: true

require "test_helper"

class FakeComfyClient
  def generate(prompt:, model:, result_id:)
    {
      prompt_id: "prompt-#{result_id}",
      seed: 123,
      filename: "#{result_id}.png",
      path: Rails.root.join("tmp/#{result_id}.png").to_s,
      bytes: 3,
      duration_sec: 0.1
    }
  end
end

class ComfyGenerationJobTest < ActiveSupport::TestCase
  test "generates every selected model result" do
    request = ImageRequest.create!(prompt: "same prompt")
    request.image_results.create!(checkpoint_name: "a.safetensors")
    request.image_results.create!(checkpoint_name: "b.safetensors")

    ComfyClient.stub(:new, FakeComfyClient.new) do
      ComfyGenerationJob.new.perform(request.id)
    end

    assert_equal "completed", request.reload.status
    assert_equal %w[completed completed], request.image_results.order(:id).pluck(:status)
    assert_equal [123, 123], request.image_results.order(:id).pluck(:seed)
  end
end
