# frozen_string_literal: true

module ImageResults
  class Regenerate
    def self.call(result:, params:)
      new(result: result, params: params).call
    end

    def initialize(result:, params:)
      @result = result
      @params = params
    end

    def call
      result.reset_for_regeneration!(prompt: prompt, width: width, height: height, steps: steps)
      result.image_request.update!(status: "queued", error_message: nil, finished_at: nil)
      ComfyResultGenerationJob.perform_async(result.id)
      result
    end

    private

    attr_reader :result, :params

    def prompt
      @prompt ||= params[:prompt].to_s.presence || result.prompt_sent_to_ai
    end

    def width
      @width ||= GenerationParams.bounded_integer(params[:width], default: result.generation_width, min: 128, max: 1536)
    end

    def height
      @height ||= GenerationParams.bounded_integer(params[:height], default: result.generation_height, min: 128, max: 1536)
    end

    def steps
      @steps ||= GenerationParams.bounded_integer(params[:steps], default: result.generation_steps, min: 1, max: 80)
    end
  end
end
