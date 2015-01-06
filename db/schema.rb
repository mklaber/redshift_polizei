# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 8) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audit_log_config", force: :cascade do |t|
    t.integer  "retention_period", default: 2592000, null: false
    t.integer  "last_update",      default: 0,       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "cache", force: :cascade do |t|
    t.string   "hashid",     null: false
    t.json     "data",       null: false
    t.integer  "expires"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cache", ["hashid"], name: "index_cache_on_hashid", unique: true, using: :btree

  create_table "export_jobs", force: :cascade do |t|
    t.string   "name",           null: false
    t.integer  "user_id",        null: false
    t.string   "success_email"
    t.string   "failure_email"
    t.boolean  "public",         null: false
    t.text     "query",          null: false
    t.string   "export_format",  null: false
    t.json     "export_options", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "export_jobs", ["public"], name: "index_export_jobs_on_public", using: :btree
  add_index "export_jobs", ["user_id"], name: "index_export_jobs_on_user_id", using: :btree

  create_table "job_runs", force: :cascade do |t|
    t.integer  "job_id",      null: false
    t.string   "job_class",   null: false
    t.integer  "user_id",     null: false
    t.string   "status",      null: false
    t.datetime "executed_at"
    t.json     "details",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "job_runs", ["job_id", "job_class"], name: "index_job_runs_on_job_id_and_job_class", using: :btree
  add_index "job_runs", ["user_id"], name: "index_job_runs_on_user_id", using: :btree

  create_table "que_jobs", primary_key: "queue", force: :cascade do |t|
    t.integer  "priority",    limit: 2, default: 100,                                        null: false
    t.datetime "run_at",                default: "now()",                                    null: false
    t.integer  "job_id",      limit: 8, default: "nextval('que_jobs_job_id_seq'::regclass)", null: false
    t.text     "job_class",                                                                  null: false
    t.json     "args",                  default: [],                                         null: false
    t.integer  "error_count",           default: 0,                                          null: false
    t.text     "last_error"
  end

  create_table "queries", force: :cascade do |t|
    t.integer  "record_time", null: false
    t.string   "db",          null: false
    t.string   "user",        null: false
    t.integer  "pid",         null: false
    t.integer  "userid",      null: false
    t.integer  "xid",         null: false
    t.text     "query",       null: false
    t.string   "logfile",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "query_type",  null: false
  end

  create_table "table_reports", force: :cascade do |t|
    t.string   "schema_name",            null: false
    t.string   "table_name",             null: false
    t.integer  "table_id",               null: false
    t.integer  "size_in_mb",             null: false
    t.float    "pct_skew_across_slices", null: false
    t.float    "pct_slices_populated",   null: false
    t.string   "dist_key"
    t.json     "sort_keys",              null: false
    t.boolean  "has_col_encodings",      null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "table_reports", ["schema_name", "table_name"], name: "index_table_reports_on_schema_name_and_table_name", unique: true, using: :btree
  add_index "table_reports", ["table_id"], name: "index_table_reports_on_table_id", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",      null: false
    t.string   "google_id",  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["google_id"], name: "index_users_on_google_id", unique: true, using: :btree

end
