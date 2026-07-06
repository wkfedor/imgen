# frozen_string_literal: true

class PromptRunsController < ApplicationController
  def show
    run = PromptRun.find(params[:id])
    render json: {
      id: run.id,
      status: run.status,
      checkpoint_name: run.checkpoint_name,
      width: run.width,
      height: run.height,
      steps: run.steps,
      seed: run.seed,
      error_message: run.error_message,
      image_url: run.image_file ? prompt_run_image_path(run) : nil
    }
  end
end
