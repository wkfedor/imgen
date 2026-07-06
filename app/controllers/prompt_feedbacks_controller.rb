# frozen_string_literal: true

class PromptFeedbacksController < ApplicationController
  def create
    run = PromptRun.includes(prompt_revision: :prompt_project).find(params[:prompt_run_id])
    revision = run.prompt_revision
    project = revision.prompt_project

    feedback = run.prompt_feedbacks.create!(feedback_params)
    PromptEvolutionSummary.append!(
      "Получен feedback пользователя",
      "project_id" => project.id,
      "revision" => revision.version_label,
      "run_id" => run.id,
      "positives" => feedback.positives,
      "negatives" => feedback.negatives,
      "keep" => feedback.keep,
      "remove" => feedback.remove,
      "next_direction" => feedback.next_direction
    )
    begin
      ai = LmStudioClient.new.evolve_prompt(project: project, revision: revision, run: run, feedback: feedback)
    rescue StandardError => e
      feedback.update!(ai_evaluation: "Ошибка LM Studio: #{e.message}")
      PromptEvolutionSummary.append!(
        "Feedback сохранён, LM Studio недоступен",
        "project_id" => project.id,
        "revision" => revision.version_label,
        "run_id" => run.id,
        "feedback_id" => feedback.id,
        "error" => e.message
      )
      redirect_to prompt_project_path(project, anchor: "run-#{run.id}"), alert: "Feedback сохранён, но LM Studio не создала новую версию: #{e.message}"
      return
    end

    next_revision = project.prompt_revisions.create!(
      parent_revision: revision,
      version_label: revision.next_child_label,
      prompt: ai.fetch("next_prompt"),
      negative_prompt: ai["negative_prompt"].presence || revision.negative_prompt,
      change_summary: ai["change_summary"],
      created_from_feedback: feedback
    )
    feedback.update!(
      ai_evaluation: [ai["why_this_should_help"], ai["risks"]].compact.join("\n\n"),
      next_prompt_revision: next_revision,
      selected_for_continuation: true
    )
    project.update!(active_prompt_revision: next_revision)
    PromptEvolutionSummary.append!(
      "LM Studio создал следующую версию",
      "project_id" => project.id,
      "parent_revision" => revision.version_label,
      "next_revision" => next_revision.version_label,
      "model" => run.checkpoint_name,
      "change_summary" => next_revision.change_summary,
      "ai_evaluation" => feedback.ai_evaluation,
      "next_prompt" => next_revision.prompt
    )

    redirect_to prompt_project_path(project, anchor: "revision-#{next_revision.id}"), notice: "Feedback сохранён. ИИ создал новую версию #{next_revision.version_label}"
  rescue StandardError => e
    run ||= PromptRun.includes(prompt_revision: :prompt_project).find_by(id: params[:prompt_run_id])
    project ||= run&.prompt_revision&.prompt_project
    if project
      PromptEvolutionSummary.append!(
        "Ошибка создания следующей версии",
        "project_id" => project.id,
        "run_id" => run&.id,
        "error" => e.message
      )
      redirect_to prompt_project_path(project), alert: "Не удалось создать следующую версию: #{e.message}"
    else
      redirect_to prompt_projects_path, alert: "Не удалось создать следующую версию: #{e.message}"
    end
  end

  private

  def feedback_params
    params.permit(:positives, :negatives, :keep, :remove, :next_direction, :user_evaluation)
  end
end
