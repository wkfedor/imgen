# frozen_string_literal: true

require "test_helper"

class GitPushesControllerTest < ActionDispatch::IntegrationTest
  test "create returns git pusher result" do
    result = { ok: true, committed: true, pushed: true, message: "done", log: "git log" }

    ImgenGitPusher.stub(:call, result) do
      post git_push_path, as: :json
    end

    assert_response :success
    assert_equal result.stringify_keys, JSON.parse(response.body)
  end

  test "create returns pusher errors" do
    error = ImgenGitPusher::Error.new("git failed", log: "details")

    ImgenGitPusher.stub(:call, -> { raise error }) do
      post git_push_path, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal false, body["ok"]
    assert_equal "git failed", body["message"]
    assert_equal "details", body["log"]
  end
end
