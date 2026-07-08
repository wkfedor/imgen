# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session

      rescue_from ActiveRecord::RecordNotFound do |error|
        render_error(error.message, status: :not_found)
      end

      rescue_from StandardError do |error|
        render_error(error.message, status: :unprocessable_entity)
      end

      private

      def render_success(data, status: :ok)
        render json: { ok: true, data: data, error: nil }, status: status
      end

      def render_error(message, status: :unprocessable_entity)
        render json: { ok: false, data: nil, error: { message: message } }, status: status
      end
    end
  end
end
