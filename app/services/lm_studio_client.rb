# frozen_string_literal: true

require "json"
require "net/http"
require "sqlite3"
require "uri"

class LmStudioClient
  DEFAULT_URL = "http://192.168.0.106:1234/v1/chat/completions"
  DEFAULT_MODEL = "qwen_qwen3.5-9b"
  CC_SWITCH_DB = "/home/feda/.cc-switch/cc-switch.db"

  def initialize(url: ENV.fetch("LM_STUDIO_URL", discovered_url), model: ENV.fetch("LM_STUDIO_MODEL", discovered_model), api_key: ENV.fetch("LM_STUDIO_API_KEY", discovered_api_key.to_s))
    @url = url
    @model = model
    @api_key = api_key.presence
  end

  def evolve_prompt(project:, revision:, run:, feedback:)
    content = chat([
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt(project: project, revision: revision, run: run, feedback: feedback) }
    ])
    parse_response(content)
  end

  private

  def chat(messages)
    uri = URI(@url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}" if @api_key.present?
    request.body = JSON.generate(model: @model, messages: messages, temperature: 0.4)

    response = Net::HTTP.start(uri.host, uri.port, read_timeout: 120, open_timeout: 5) { |http| http.request(request) }
    raise "LM Studio failed #{response.code}: #{response.body[0, 500]}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("choices").first.fetch("message").fetch("content")
  end

  def system_prompt
    <<~TEXT
      Ты помощник для эволюции промптов генерации изображений.
      Нужно улучшать промпт маленькими понятными шагами по feedback пользователя.
      Не добавляй лишние идеи. Сохраняй одобренные качества, исправляй указанные минусы.
      Ответь строго JSON-объектом с ключами: next_prompt, negative_prompt, change_summary, why_this_should_help, risks.
    TEXT
  end

  def user_prompt(project:, revision:, run:, feedback:)
    <<~TEXT
      Проект: #{project.title}
      Исходная цель: #{project.original_goal}
      Критерии готовности: #{project.acceptance_criteria}

      Текущая версия: #{revision.version_label}
      Текущий промпт:
      #{revision.prompt}

      Negative prompt:
      #{revision.negative_prompt}

      Модель: #{run.checkpoint_name}
      Параметры: #{run.width}x#{run.height}, steps=#{run.steps}
      Картинка: #{run.image_path || run.image_result&.path}

      Feedback пользователя.
      Хорошо: #{feedback.positives}
      Плохо: #{feedback.negatives}
      Сохранить: #{feedback.keep}
      Убрать: #{feedback.remove}
      Куда двигаться: #{feedback.next_direction}

      Сделай следующую версию промпта для этой же модели.
    TEXT
  end

  def parse_response(content)
    JSON.parse(json_object(content))
  rescue JSON::ParserError
    {
      "next_prompt" => content.to_s.strip,
      "negative_prompt" => "",
      "change_summary" => "LM Studio вернул не JSON; ответ сохранён как промпт",
      "why_this_should_help" => "Требуется ручная проверка ответа LM Studio",
      "risks" => "Ответ не был структурирован"
    }
  end

  def json_object(content)
    text = content.to_s.strip
    fenced = text.match(/```(?:json)?\s*(.*?)\s*```/m)
    text = fenced[1].strip if fenced
    start_index = text.index("{")
    end_index = text.rindex("}")
    return text unless start_index && end_index && end_index >= start_index

    text[start_index..end_index]
  end

  def discovered_url
    base = discovered_config["baseUrl"].presence || DEFAULT_URL.delete_suffix("/chat/completions")
    "#{base.delete_suffix("/")}/chat/completions"
  end

  def discovered_model
    models = Array(discovered_config["models"])
    models.find { |model| model["id"] == DEFAULT_MODEL }&.fetch("id", nil) || DEFAULT_MODEL
  end

  def discovered_api_key
    discovered_config["apiKey"]
  end

  def discovered_config
    @discovered_config ||= begin
      return {} unless File.file?(CC_SWITCH_DB)

      db = SQLite3::Database.new(CC_SWITCH_DB)
      raw = db.get_first_value("select settings_config from providers where id = 'lmstudio' and app_type = 'openclaw' limit 1")
      raw.present? ? JSON.parse(raw) : {}
    rescue StandardError
      {}
    ensure
      db&.close
    end
  end
end
