# frozen_string_literal: true

require "test_helper"

class FakeDeleteComfyClient
  attr_reader :deleted

  def initialize
    @deleted = []
  end

  def delete_remote_image(filename:, subfolder:, type:, prefix: nil)
    @deleted << { filename: filename, subfolder: subfolder, type: type, prefix: prefix }
    true
  end
end

class ImageResultTest < ActiveSupport::TestCase
  test "delete_image_files removes local file remote file and clears metadata" do
    request = ImageRequest.create!(prompt: "prompt", status: "completed")
    file = Rails.root.join("storage/generated/delete-image-result-test.png")
    File.binwrite(file, "png")
    result = request.image_results.create!(
      checkpoint_name: "model.safetensors",
      status: "completed",
      prompt_id: "prompt-1",
      seed: 123,
      filename: "local.png",
      path: file.to_s,
      bytes: 3,
      duration_sec: 0.1,
      remote_filename: "remote.png",
      remote_subfolder: "",
      remote_type: "output"
    )
    client = FakeDeleteComfyClient.new

    ComfyClient.stub(:new, client) do
      deleted = result.delete_image_files!
      assert_equal({ local_deleted: true, remote_deleted: true }, deleted)
    end

    assert_not file.exist?
    assert_equal [{ filename: "remote.png", subfolder: "", type: "output", prefix: nil }], client.deleted
    assert_equal "deleted", result.reload.status
    assert_nil result.path
    assert_nil result.remote_filename
  ensure
    File.delete(file) if file&.exist?
  end

  test "delete_image_files infers remote filename for old records" do
    request = ImageRequest.create!(prompt: "prompt", status: "completed")
    result = request.image_results.create!(
      checkpoint_name: "model.safetensors",
      status: "completed",
      prompt_id: "abc-123",
      filename: "imgen_1_model_00001__abc-123.png",
      path: nil
    )
    client = FakeDeleteComfyClient.new

    ComfyClient.stub(:new, client) do
      deleted = result.delete_image_files!
      assert_equal({ local_deleted: false, remote_deleted: true }, deleted)
    end

    assert_equal [{ filename: "imgen_1_model_00001_.png", subfolder: nil, type: nil, prefix: "imgen_1_model" }], client.deleted
  end
end
