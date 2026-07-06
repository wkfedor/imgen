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
      duration_sec: 0.1,
      remote_filename: "remote-#{result_id}.png",
      remote_subfolder: "",
      remote_type: "output"
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
    assert_equal ["remote-#{request.image_results.order(:id).first.id}.png", "remote-#{request.image_results.order(:id).second.id}.png"], request.image_results.order(:id).pluck(:remote_filename)
  end
end
