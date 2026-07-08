# frozen_string_literal: true

module ImageRequests
  class Retry
    def self.call(request:, params:)
      new(request: request, params: params).call
    end

    def initialize(request:, params:)
      @request = request
      @params = params
    end

    def call
      request.update!(prompt: prompt, width: width, height: height, steps: steps, status: "queued", error_message: nil, started_at: nil, finished_at: nil)
      request.image_results.update_all(
        status: "queued",
        error_message: nil,
        prompt_id: nil,
        seed: nil,
        filename: nil,
        path: nil,
        bytes: nil,
        duration_sec: nil,
        actual_prompt: prompt,
        width: width,
        height: height,
        steps: steps,
        remote_filename: nil,
        remote_subfolder: nil,
        remote_type: nil,
        updated_at: Time.current
      )
      request.image_results.order(:id).pluck(:id).each do |result_id|
        ComfyResultGenerationJob.perform_async(result_id)
      end
      request
    end

    private

    attr_reader :request, :params

    def prompt
      @prompt ||= params[:prompt].to_s.presence || request.prompt
    end

    def width
      @width ||= GenerationParams.bounded_integer(params[:width], default: request.width, min: 128, max: 1536)
    end

    def height
      @height ||= GenerationParams.bounded_integer(params[:height], default: request.height, min: 128, max: 1536)
    end

    def steps
      @steps ||= GenerationParams.bounded_integer(params[:steps], default: request.steps, min: 1, max: 80)
    end
  end
end
