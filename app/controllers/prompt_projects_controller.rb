# frozen_string_literal: true

class PromptProjectsController < ApplicationController
  def index
    @projects = PromptProject.includes(:active_prompt_revision).recent_first.limit(50)
  end

  def create
    project = PromptProject.create!(
      title: params[:title].to_s.strip,
      original_goal: params[:original_goal].to_s.strip,
      acceptance_criteria: params[:acceptance_criteria].to_s.strip
    )
    revision = project.create_initial_revision!(prompt: params[:prompt].to_s.strip, negative_prompt: params[:negative_prompt].to_s.strip.presence)
    PromptEvolutionSummary.append!(
      "Создан AI-проект",
      "project_id" => project.id,
      "revision" => revision.version_label,
      "title" => project.title,
      "goal" => project.original_goal,
      "prompt" => revision.prompt
    )

    redirect_to prompt_project_path(project), notice: "Проект создан"
  rescue StandardError => e
    redirect_to prompt_projects_path, alert: e.message
  end

  def show
    @project = PromptProject.includes(prompt_revisions: { prompt_runs: :prompt_feedbacks }).find(params[:id])
    @active_revision = @project.active_prompt_revision || @project.prompt_revisions.oldest_first.last
    @models = ComfyClient.new.models
    @sidekiq_process_count = sidekiq_process_count
  rescue ActiveRecord::RecordNotFound
    redirect_to prompt_projects_path, alert: "Проект не найден"
  rescue StandardError => e
    @models = []
    @model_error = e.message
    @sidekiq_process_count = sidekiq_process_count
  end

  def run
    project = PromptProject.find(params[:id])
    revision = project.prompt_revisions.find(params[:prompt_revision_id])
    raise "Выберите одну модель" if params[:checkpoint_name].to_s.strip.blank?

    run = revision.prompt_runs.create!(
      checkpoint_name: params[:checkpoint_name].to_s.strip,
      width: bounded_integer(params[:width], default: 768, min: 128, max: 1536),
      height: bounded_integer(params[:height], default: 1344, min: 128, max: 1536),
      steps: bounded_integer(params[:steps], default: 60, min: 1, max: 80)
    )
    PromptEvolutionSummary.append!(
      "Запущен прогон AI-версии",
      "project_id" => project.id,
      "revision" => revision.version_label,
      "run_id" => run.id,
      "model" => run.checkpoint_name,
      "params" => "#{run.width}x#{run.height}, steps=#{run.steps}",
      "prompt" => revision.prompt
    )
    PromptRunGenerationJob.perform_async(run.id)

    redirect_to prompt_project_path(project, anchor: "run-#{run.id}"), notice: "Прогон ##{run.id} добавлен в очередь"
  rescue StandardError => e
    redirect_to prompt_project_path(params[:id]), alert: e.message
  end

  def image
    run = PromptRun.find(params[:id])
    file = run.image_file
    raise ActiveRecord::RecordNotFound unless file

    send_file file, type: "image/png", disposition: "inline"
  end

  private

  def bounded_integer(value, default:, min:, max:)
    parsed = Integer(value.presence || default)
    [[parsed, min].max, max].min
  rescue ArgumentError, TypeError
    default
  end

  def sidekiq_process_count
    Sidekiq::ProcessSet.new.size
  rescue StandardError
    nil
  end
end
