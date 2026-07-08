# frozen_string_literal: true

require "test_helper"

class FakeComfyClient
  def generate(prompt:, model:, result_id:, width: 1024, height: 1024, steps: 24)
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
  test "enqueues one generation job per selected model result" do
    ComfyResultGenerationJob.jobs.clear

    request = ImageRequest.create!(prompt: "same prompt")
    first_result = request.image_results.create!(checkpoint_name: "a.safetensors")
    second_result = request.image_results.create!(checkpoint_name: "b.safetensors")

    ComfyGenerationJob.new.perform(request.id)

    assert_equal "queued", request.reload.status
    assert_equal 2, ComfyResultGenerationJob.jobs.size
    assert_equal [first_result.id, second_result.id], ComfyResultGenerationJob.jobs.map { |job| job["args"].first }
    assert_equal ["comfy_generation", "comfy_generation"], ComfyResultGenerationJob.jobs.map { |job| job["queue"] }
  end

  test "result generation job generates one image and refreshes aggregate status" do
    request = ImageRequest.create!(prompt: "same prompt")
    first_result = request.image_results.create!(checkpoint_name: "a.safetensors")
    second_result = request.image_results.create!(checkpoint_name: "b.safetensors")

    ComfyClient.stub(:new, FakeComfyClient.new) do
      ComfyResultGenerationJob.new.perform(first_result.id)
    end

    assert_equal "running", request.reload.status
    assert_equal "completed", first_result.reload.status
    assert_equal "queued", second_result.reload.status

    ComfyClient.stub(:new, FakeComfyClient.new) do
      ComfyResultGenerationJob.new.perform(second_result.id)
    end

    assert_equal "completed", request.reload.status
    assert_equal %w[completed completed], request.image_results.order(:id).pluck(:status)
    assert_equal [123, 123], request.image_results.order(:id).pluck(:seed)
    assert_equal ["remote-#{request.image_results.order(:id).first.id}.png", "remote-#{request.image_results.order(:id).second.id}.png"], request.image_results.order(:id).pluck(:remote_filename)
  end
end
