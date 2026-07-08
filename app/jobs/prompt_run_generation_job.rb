# frozen_string_literal: true

class PromptRunGenerationJob
  include Sidekiq::Job

  sidekiq_options queue: :comfy_generation, retry: false

  def perform(prompt_run_id)
    run = PromptRun.includes(:prompt_revision).find(prompt_run_id)
    revision = run.prompt_revision
    run.update!(status: "running", started_at: Time.current, error_message: nil)

    generated = ComfyClient.new.generate(
      prompt: revision.prompt,
      model: run.checkpoint_name,
      result_id: "prompt_run_#{run.id}",
      width: run.width,
      height: run.height,
      steps: run.steps
    )
    run.update!(
      status: "completed",
      seed: generated.fetch(:seed),
      image_path: generated.fetch(:path),
      finished_at: Time.current
    )
    PromptEvolutionSummary.append!(
      "Прогон AI-версии завершён",
      "project_id" => revision.prompt_project_id,
      "revision" => revision.version_label,
      "run_id" => run.id,
      "model" => run.checkpoint_name,
      "seed" => generated.fetch(:seed),
      "image_path" => generated.fetch(:path),
      "duration_sec" => generated[:duration_sec]
    )
  rescue StandardError => e
    run&.update!(status: "failed", error_message: e.message, finished_at: Time.current)
    PromptEvolutionSummary.append!(
      "Ошибка прогона AI-версии",
      "run_id" => run&.id || prompt_run_id,
      "error" => e.message
    )
  end

end
