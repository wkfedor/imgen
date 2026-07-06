# frozen_string_literal: true

class GitPushesController < ApplicationController
  def create
    result = Timeout.timeout(120) { ImgenGitPusher.call }
    status = result[:ok] ? :ok : :unprocessable_entity

    render json: result, status: status
  rescue Timeout::Error
    render json: {
      ok: false,
      message: "Таймаут 120 с: git push ещё выполняется. Повторите или выполните push вручную."
    }, status: :request_timeout
  rescue ImgenGitPusher::Error => e
    Rails.logger.error("[imgen-git] #{e.message}")
    render json: { ok: false, message: e.message, log: e.log }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[imgen-git] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    render json: { ok: false, message: e.message }, status: :internal_server_error
  end
end
