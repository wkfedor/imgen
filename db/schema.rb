# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_07_06_193000) do
  create_table "image_requests", force: :cascade do |t|
    t.text "prompt", null: false
    t.string "status", default: "queued", null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "width", default: 768, null: false
    t.integer "height", default: 1344, null: false
    t.integer "steps", default: 60, null: false
    t.index ["created_at"], name: "index_image_requests_on_created_at"
    t.index ["status"], name: "index_image_requests_on_status"
  end

  create_table "image_results", force: :cascade do |t|
    t.integer "image_request_id", null: false
    t.string "checkpoint_name", null: false
    t.string "status", default: "queued", null: false
    t.string "prompt_id"
    t.integer "seed"
    t.string "filename"
    t.string "path"
    t.integer "bytes"
    t.float "duration_sec"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "remote_filename"
    t.string "remote_subfolder"
    t.string "remote_type"
    t.text "actual_prompt"
    t.integer "width"
    t.integer "height"
    t.integer "steps"
    t.index ["checkpoint_name"], name: "index_image_results_on_checkpoint_name"
    t.index ["image_request_id"], name: "index_image_results_on_image_request_id"
    t.index ["status"], name: "index_image_results_on_status"
  end

  create_table "prompt_feedbacks", force: :cascade do |t|
    t.integer "prompt_run_id", null: false
    t.text "positives"
    t.text "negatives"
    t.text "keep"
    t.text "remove"
    t.text "next_direction"
    t.text "ai_evaluation"
    t.text "user_evaluation"
    t.boolean "selected_for_continuation", default: false, null: false
    t.integer "next_prompt_revision_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["next_prompt_revision_id"], name: "index_prompt_feedbacks_on_next_prompt_revision_id"
    t.index ["prompt_run_id"], name: "index_prompt_feedbacks_on_prompt_run_id"
  end

  create_table "prompt_projects", force: :cascade do |t|
    t.string "title", null: false
    t.text "original_goal", null: false
    t.text "acceptance_criteria"
    t.string "status", default: "active", null: false
    t.integer "active_prompt_revision_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prompt_revisions", force: :cascade do |t|
    t.integer "prompt_project_id", null: false
    t.integer "parent_revision_id"
    t.string "version_label", null: false
    t.text "prompt", null: false
    t.text "negative_prompt"
    t.text "change_summary"
    t.integer "created_from_feedback_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_revision_id"], name: "index_prompt_revisions_on_parent_revision_id"
    t.index ["prompt_project_id"], name: "index_prompt_revisions_on_prompt_project_id"
  end

  create_table "prompt_runs", force: :cascade do |t|
    t.integer "prompt_revision_id", null: false
    t.integer "image_result_id"
    t.string "checkpoint_name", null: false
    t.integer "width", default: 384, null: false
    t.integer "height", default: 384, null: false
    t.integer "steps", default: 18, null: false
    t.integer "seed"
    t.string "status", default: "queued", null: false
    t.string "image_path"
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["image_result_id"], name: "index_prompt_runs_on_image_result_id"
    t.index ["prompt_revision_id"], name: "index_prompt_runs_on_prompt_revision_id"
  end

  add_foreign_key "image_results", "image_requests"
  add_foreign_key "prompt_feedbacks", "prompt_revisions", column: "next_prompt_revision_id"
  add_foreign_key "prompt_feedbacks", "prompt_runs"
  add_foreign_key "prompt_projects", "prompt_revisions", column: "active_prompt_revision_id"
  add_foreign_key "prompt_revisions", "prompt_feedbacks", column: "created_from_feedback_id"
  add_foreign_key "prompt_revisions", "prompt_projects"
  add_foreign_key "prompt_revisions", "prompt_revisions", column: "parent_revision_id"
  add_foreign_key "prompt_runs", "image_results"
  add_foreign_key "prompt_runs", "prompt_revisions"
end
