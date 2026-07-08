# frozen_string_literal: true

class GenerationParams
  def self.bounded_integer(value, default:, min:, max:)
    parsed = Integer(value.presence || default)
    [[parsed, min].max, max].min
  rescue ArgumentError, TypeError
    default
  end
end
