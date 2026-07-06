# frozen_string_literal: true

require "fileutils"

class PromptEvolutionSummary
  PATH = Rails.root.join("tmp/prompt_evolution_summary.md")

  def self.append!(title, lines = {})
    FileUtils.mkdir_p(PATH.dirname)
    File.open(PATH, "a") do |file|
      file.puts
      file.puts "## #{Time.current.strftime('%Y-%m-%d %H:%M:%S')} - #{title}"
      lines.each do |key, value|
        next if value.blank?

        file.puts
        file.puts "- #{key}: #{value.to_s.gsub("\n", "\n  ")}"
      end
    end
  end
end
