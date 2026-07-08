# frozen_string_literal: true

module ImageRequests
  class Create
    def self.call(params:, source: "web")
      new(params: params, source: source).call
    end

    def initialize(params:, source: "web")
      @params = params
      @source = source
    end

    def call
      raise "Промпт пустой" if prompt.blank?
      raise "Выберите хотя бы одну модель" if models.blank?

      request = ImageRequest.create!(prompt: prompt, width: width, height: height, steps: steps, source: source)
      models.each do |model|
        result = request.image_results.create!(checkpoint_name: model, actual_prompt: prompt, width: width, height: height, steps: steps)
        ComfyResultGenerationJob.perform_async(result.id)
      end
      request
    end

    private

    attr_reader :params, :source

    def prompt
      @prompt ||= params[:prompt].to_s.strip
    end

    def models
      @models ||= Array(params[:models]).map(&:to_s).map(&:strip).reject(&:blank?)
    end

    def width
      @width ||= GenerationParams.bounded_integer(params[:width], default: 768, min: 128, max: 1536)
    end

    def height
      @height ||= GenerationParams.bounded_integer(params[:height], default: 1344, min: 128, max: 1536)
    end

    def steps
      @steps ||= GenerationParams.bounded_integer(params[:steps], default: 60, min: 1, max: 80)
    end
  end
end
