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

ActiveRecord::Schema[7.1].define(version: 2026_07_06_000300) do
  create_table "image_requests", force: :cascade do |t|
    t.text "prompt", null: false
    t.string "status", default: "queued", null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["checkpoint_name"], name: "index_image_results_on_checkpoint_name"
    t.index ["image_request_id"], name: "index_image_results_on_image_request_id"
    t.index ["status"], name: "index_image_results_on_status"
  end

  add_foreign_key "image_results", "image_requests"
end
