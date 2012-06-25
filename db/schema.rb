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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120625052858) do

  create_table "accounts", :force => true do |t|
    t.boolean  "card_verified"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "domain"
    t.boolean  "activated",                 :default => false
    t.boolean  "record_calls",              :default => false
    t.string   "recurly_account_code"
    t.string   "subscription_name"
    t.integer  "subscription_count"
    t.boolean  "subscription_active",       :default => false
    t.string   "recurly_subscription_uuid"
    t.boolean  "autorecharge_enabled",      :default => false
    t.float    "autorecharge_trigger"
    t.float    "autorecharge_amount"
    t.integer  "lock_version",              :default => 0
    t.string   "status"
    t.string   "abandonment"
  end

  create_table "answers", :force => true do |t|
    t.integer  "voter_id",             :null => false
    t.integer  "question_id",          :null => false
    t.integer  "possible_response_id", :null => false
    t.datetime "created_at"
    t.integer  "campaign_id"
    t.integer  "caller_id"
    t.integer  "call_attempt_id"
  end

  add_index "answers", ["voter_id", "question_id"], :name => "index_answers_on_voter_id_and_question_id"

  create_table "billing_accounts", :force => true do |t|
    t.integer  "account_id"
    t.string   "cc"
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "cardtype"
    t.integer  "expires_month"
    t.integer  "expires_year"
    t.string   "last4"
    t.string   "zip"
    t.string   "address1"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "name"
    t.string   "checking_account_number"
    t.string   "bank_routing_number"
    t.string   "drivers_license_number"
    t.string   "drivers_license_state"
    t.string   "checking_account_type"
  end

  create_table "blocked_numbers", :force => true do |t|
    t.string   "number"
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "campaign_id"
  end

  create_table "call_attempts", :force => true do |t|
    t.integer  "voter_id"
    t.string   "sid"
    t.string   "status"
    t.integer  "campaign_id"
    t.datetime "call_start"
    t.datetime "call_end"
    t.integer  "caller_id"
    t.datetime "connecttime"
    t.integer  "caller_session_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "result"
    t.string   "result_digit"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.string   "tStatus"
    t.integer  "tDuration"
    t.integer  "tFlags"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.float    "tPrice"
    t.string   "dialer_mode"
    t.datetime "scheduled_date"
    t.string   "recording_url"
    t.integer  "recording_duration"
    t.datetime "wrapup_time"
    t.integer  "payment_id"
    t.integer  "call_id"
    t.boolean  "voter_response_processed", :default => false
    t.boolean  "debited",                  :default => false
  end

  add_index "call_attempts", ["call_end"], :name => "index_call_attempts_on_call_end"
  add_index "call_attempts", ["call_id"], :name => "index_call_attempts_on_call_id"
  add_index "call_attempts", ["caller_id", "wrapup_time"], :name => "index_call_attempts_on_caller_id_and_wrapup_time"
  add_index "call_attempts", ["caller_session_id"], :name => "index_call_attempts_on_caller_session_id"
  add_index "call_attempts", ["campaign_id", "call_end"], :name => "index_call_attempts_on_campaign_id_and_call_end"
  add_index "call_attempts", ["campaign_id", "wrapup_time"], :name => "index_call_attempts_on_campaign_id_and_wrapup_time"
  add_index "call_attempts", ["campaign_id"], :name => "index_call_attempts_on_campaign_id"
  add_index "call_attempts", ["debited", "call_end"], :name => "index_call_attempts_on_debited_and_call_end"
  add_index "call_attempts", ["voter_id"], :name => "index_call_attempts_on_voter_id"
  add_index "call_attempts", ["voter_response_processed", "status"], :name => "index_call_attempts_on_voter_response_processed_and_status"

  create_table "call_responses", :force => true do |t|
    t.integer  "call_attempt_id"
    t.string   "response"
    t.integer  "recording_response_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "robo_recording_id"
    t.integer  "times_attempted",       :default => 0
    t.integer  "campaign_id"
  end

  create_table "caller_identities", :force => true do |t|
    t.string   "session_key"
    t.integer  "caller_session_id"
    t.integer  "caller_id"
    t.string   "pin"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "caller_sessions", :force => true do |t|
    t.integer  "caller_id"
    t.integer  "campaign_id"
    t.datetime "endtime"
    t.datetime "starttime"
    t.string   "sid"
    t.boolean  "available_for_call",   :default => false
    t.integer  "voter_in_progress_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "on_call",              :default => false
    t.string   "caller_number"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.string   "tStatus"
    t.integer  "tDuration"
    t.integer  "tFlags"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.float    "tPrice"
    t.integer  "attempt_in_progress"
    t.string   "session_key"
    t.integer  "lock_version",         :default => 0
    t.integer  "payment_id"
    t.string   "state"
    t.string   "type"
    t.string   "digit"
    t.boolean  "debited",              :default => false
    t.integer  "question_id"
  end

  add_index "caller_sessions", ["caller_id"], :name => "index_caller_sessions_on_caller_id"
  add_index "caller_sessions", ["campaign_id"], :name => "index_caller_sessions_on_campaign_id"
  add_index "caller_sessions", ["sid"], :name => "index_caller_sessions_on_sid"

  create_table "callers", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "pin"
    t.integer  "account_id"
    t.boolean  "active",         :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password"
    t.boolean  "is_phones_only", :default => false
    t.integer  "campaign_id"
  end

  create_table "calls", :force => true do |t|
    t.integer  "call_attempt_id"
    t.string   "state"
    t.string   "conference_name"
    t.text     "conference_history"
    t.string   "account_sid"
    t.string   "to_zip"
    t.string   "from_state"
    t.string   "called"
    t.string   "from_country"
    t.string   "caller_country"
    t.string   "called_zip"
    t.string   "direction"
    t.string   "from_city"
    t.string   "called_country"
    t.string   "caller_state"
    t.string   "call_sid"
    t.string   "called_state"
    t.string   "from"
    t.string   "caller_zip"
    t.string   "from_zip"
    t.string   "application_sid"
    t.string   "call_status"
    t.string   "to_city"
    t.string   "to_state"
    t.string   "to"
    t.string   "to_country"
    t.string   "caller_city"
    t.string   "api_version"
    t.string   "caller"
    t.string   "called_city"
    t.string   "answered_by"
    t.integer  "recording_duration"
    t.string   "recording_url"
    t.datetime "waiting_at"
    t.datetime "ended_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "questions"
    t.text     "notes"
    t.text     "all_states"
  end

  create_table "campaigns", :force => true do |t|
    t.string   "campaign_id"
    t.string   "group_id"
    t.string   "name"
    t.string   "keypad_0"
    t.integer  "account_id"
    t.integer  "script_id"
    t.boolean  "active",                   :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "ratio_2",                  :default => 33.0
    t.float    "ratio_3",                  :default => 20.0
    t.float    "ratio_4",                  :default => 12.0
    t.float    "ratio_override",           :default => 0.0
    t.string   "ending_window_method",     :default => "Not used"
    t.string   "caller_id"
    t.boolean  "caller_id_verified",       :default => false
    t.boolean  "use_answering",            :default => true
    t.string   "type",                     :default => "preview"
    t.integer  "recording_id"
    t.boolean  "use_recordings",           :default => false
    t.integer  "max_calls_per_caller",     :default => 20
    t.string   "callin_number",            :default => "4157020991"
    t.boolean  "use_web_ui",               :default => true
    t.integer  "answer_detection_timeout", :default => 20
    t.boolean  "calls_in_progress",        :default => false
    t.boolean  "robo",                     :default => false
    t.integer  "recycle_rate",             :default => 1
    t.boolean  "amd_turn_off"
    t.boolean  "answering_machine_detect"
    t.time     "start_time"
    t.time     "end_time"
    t.string   "time_zone"
    t.float    "acceptable_abandon_rate"
    t.integer  "voicemail_script_id"
  end

  create_table "campaigns_voter_lists", :id => false, :force => true do |t|
    t.integer "campaign_id"
    t.integer "voter_list_id"
  end

  create_table "custom_voter_field_values", :force => true do |t|
    t.integer "voter_id"
    t.integer "custom_voter_field_id"
    t.string  "value"
  end

  add_index "custom_voter_field_values", ["voter_id"], :name => "index_custom_voter_field_values_on_voter_id"

  create_table "custom_voter_fields", :force => true do |t|
    t.string  "name",       :null => false
    t.integer "account_id"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "downloaded_reports", :force => true do |t|
    t.integer  "user_id"
    t.string   "link"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "campaign_id"
  end

  create_table "dumps", :force => true do |t|
    t.integer  "request_id"
    t.integer  "first_line"
    t.integer  "last_line"
    t.integer  "completed_id"
    t.integer  "completed_lineno"
    t.float    "duration"
    t.integer  "status"
    t.string   "url"
    t.integer  "params_id"
    t.integer  "params_line"
    t.string   "params"
    t.string   "guid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "dumps", ["guid"], :name => "index_dumps_on_guid"

  create_table "families", :force => true do |t|
    t.integer  "voter_id"
    t.string   "Phone"
    t.string   "CustomID"
    t.string   "LastName"
    t.string   "FirstName"
    t.string   "MiddleName"
    t.string   "Suffix"
    t.string   "Email"
    t.string   "result"
    t.integer  "campaign_id"
    t.integer  "account_id"
    t.boolean  "active",                 :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status",                 :default => "not called"
    t.integer  "voter_list_id"
    t.integer  "caller_session_id"
    t.boolean  "call_back",              :default => false
    t.integer  "caller_id"
    t.string   "result_digit"
    t.string   "Age"
    t.string   "Gender"
    t.integer  "attempt_id"
    t.datetime "result_date"
    t.integer  "last_call_attempt_id"
    t.datetime "last_call_attempt_time"
  end

  create_table "lists", :force => true do |t|
    t.string   "name"
    t.integer  "group_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "moderators", :force => true do |t|
    t.integer  "caller_session_id"
    t.string   "call_sid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "session"
    t.string   "active"
    t.integer  "account_id"
  end

  create_table "note_responses", :force => true do |t|
    t.integer "voter_id",        :null => false
    t.integer "note_id",         :null => false
    t.string  "response"
    t.integer "call_attempt_id"
    t.integer "campaign_id"
  end

  create_table "notes", :force => true do |t|
    t.text    "note",      :null => false
    t.integer "script_id", :null => false
  end

  create_table "payments", :force => true do |t|
    t.float    "amount_paid"
    t.float    "amount_remaining"
    t.integer  "recurly_transaction_uuid"
    t.integer  "account_id"
    t.string   "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "possible_responses", :force => true do |t|
    t.integer "question_id"
    t.integer "keypad"
    t.string  "value"
    t.boolean "retry",                   :default => false
    t.integer "possible_response_order"
  end

  create_table "questions", :force => true do |t|
    t.integer "script_id",      :null => false
    t.text    "text",           :null => false
    t.integer "question_order"
  end

  create_table "recording_responses", :force => true do |t|
    t.integer "robo_recording_id"
    t.string  "response"
    t.integer "keypad"
  end

  create_table "recordings", :force => true do |t|
    t.integer  "account_id"
    t.integer  "active",            :default => 1
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.string   "file_file_size"
    t.datetime "file_updated_at"
  end

  create_table "robo_recordings", :force => true do |t|
    t.integer  "script_id"
    t.string   "name"
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.integer  "file_file_size"
    t.datetime "file_updated_at"
  end

  create_table "scripts", :force => true do |t|
    t.string   "name"
    t.text     "script"
    t.boolean  "active",                              :default => true
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "keypad_1"
    t.text     "keypad_2"
    t.text     "keypad_3"
    t.text     "keypad_4"
    t.text     "keypad_5"
    t.text     "keypad_6"
    t.text     "keypad_7"
    t.text     "keypad_8"
    t.text     "keypad_9"
    t.text     "keypad_10"
    t.text     "keypad_11"
    t.text     "keypad_12"
    t.text     "keypad_13"
    t.text     "keypad_14"
    t.text     "keypad_15"
    t.text     "keypad_16"
    t.text     "keypad_17"
    t.text     "keypad_18"
    t.text     "keypad_19"
    t.text     "keypad_20"
    t.text     "keypad_21"
    t.text     "keypad_22"
    t.text     "keypad_23"
    t.text     "keypad_24"
    t.text     "keypad_25"
    t.text     "keypad_26"
    t.text     "keypad_27"
    t.text     "keypad_28"
    t.text     "keypad_29"
    t.text     "keypad_30"
    t.text     "keypad_31"
    t.text     "keypad_32"
    t.text     "keypad_33"
    t.text     "keypad_34"
    t.text     "keypad_35"
    t.text     "keypad_36"
    t.text     "keypad_37"
    t.text     "keypad_38"
    t.text     "keypad_39"
    t.text     "keypad_40"
    t.text     "keypad_41"
    t.text     "keypad_42"
    t.text     "keypad_43"
    t.text     "keypad_44"
    t.text     "keypad_45"
    t.text     "keypad_46"
    t.text     "keypad_47"
    t.text     "keypad_48"
    t.text     "keypad_49"
    t.string   "incompletes"
    t.text     "voter_fields",  :limit => 2147483647
    t.text     "result_set_1"
    t.text     "result_set_2"
    t.text     "result_set_3"
    t.text     "result_set_4"
    t.text     "result_set_5"
    t.text     "result_set_6"
    t.text     "result_set_7"
    t.text     "result_set_8"
    t.text     "result_set_9"
    t.text     "result_set_10"
    t.string   "note_1"
    t.string   "note_2"
    t.string   "note_3"
    t.string   "note_4"
    t.string   "note_5"
    t.string   "note_6"
    t.string   "note_7"
    t.string   "note_8"
    t.string   "note_9"
    t.string   "note_10"
    t.boolean  "robo",                                :default => false
    t.text     "result_set_11"
    t.text     "result_set_12"
    t.text     "result_set_13"
    t.text     "result_set_14"
    t.text     "result_set_15"
    t.text     "result_set_16"
    t.string   "note_11"
    t.string   "note_12"
    t.string   "note_13"
    t.string   "note_14"
    t.string   "note_15"
    t.string   "note_16"
    t.boolean  "for_voicemail"
  end

  create_table "seos", :force => true do |t|
    t.string   "action"
    t.string   "controller"
    t.string   "crmkey"
    t.string   "title"
    t.string   "keywords"
    t.string   "description"
    t.text     "content",     :limit => 2147483647
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "version"
  end

  create_table "simulated_values", :force => true do |t|
    t.integer  "campaign_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "best_dials"
    t.float    "best_conversation"
    t.float    "longest_conversation"
    t.float    "best_wrapup_time"
  end

  create_table "transfer_attempts", :force => true do |t|
    t.integer  "transfer_id"
    t.integer  "caller_session_id"
    t.integer  "call_attempt_id"
    t.integer  "script_id"
    t.integer  "campaign_id"
    t.datetime "call_start"
    t.datetime "call_end"
    t.string   "status"
    t.datetime "connecttime"
    t.string   "sid"
    t.string   "session_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "transfer_type"
    t.float    "tPrice"
    t.string   "tStatus"
    t.string   "tCallSegmentSid"
    t.string   "tAccountSid"
    t.string   "tCalled"
    t.string   "tCaller"
    t.string   "tPhoneNumberSid"
    t.datetime "tStartTime"
    t.datetime "tEndTime"
    t.integer  "tDuration"
    t.integer  "tFlags"
  end

  create_table "transfers", :force => true do |t|
    t.string   "label"
    t.string   "phone_number"
    t.string   "transfer_type"
    t.integer  "script_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "fname"
    t.string   "lname"
    t.string   "orgname"
    t.string   "email"
    t.boolean  "active",              :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "hashed_password"
    t.string   "salt"
    t.string   "password_reset_code"
    t.string   "phone"
    t.integer  "account_id"
    t.string   "role"
  end

  create_table "voter_lists", :force => true do |t|
    t.string   "name"
    t.string   "account_id"
    t.boolean  "active",      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "campaign_id"
    t.boolean  "enabled",     :default => true
  end

  add_index "voter_lists", ["account_id", "name"], :name => "index_voter_lists_on_user_id_and_name", :unique => true

  create_table "voters", :force => true do |t|
    t.string   "Phone"
    t.string   "CustomID"
    t.string   "LastName"
    t.string   "FirstName"
    t.string   "MiddleName"
    t.string   "Suffix"
    t.string   "Email"
    t.string   "result"
    t.integer  "caller_session_id"
    t.integer  "campaign_id"
    t.integer  "account_id"
    t.boolean  "active",                 :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status",                 :default => "not called"
    t.integer  "voter_list_id"
    t.boolean  "call_back",              :default => false
    t.integer  "caller_id"
    t.string   "result_digit"
    t.integer  "attempt_id"
    t.datetime "result_date"
    t.integer  "last_call_attempt_id"
    t.datetime "last_call_attempt_time"
    t.integer  "num_family",             :default => 1
    t.integer  "family_id_answered"
    t.text     "result_json"
    t.datetime "scheduled_date"
    t.string   "address"
    t.string   "city"
    t.string   "state"
    t.string   "zip_code"
    t.string   "country"
    t.datetime "skipped_time"
    t.string   "priority"
    t.integer  "lock_version",           :default => 0
    t.boolean  "enabled",                :default => true
  end

  add_index "voters", ["Phone", "voter_list_id"], :name => "index_voters_on_Phone_and_voter_list_id"
  add_index "voters", ["Phone"], :name => "index_voters_on_Phone"
  add_index "voters", ["attempt_id"], :name => "index_voters_on_attempt_id"
  add_index "voters", ["caller_session_id"], :name => "index_voters_on_caller_session_id"
  add_index "voters", ["campaign_id", "active", "status", "call_back"], :name => "index_voters_on_campaign_id_and_active_and_status_and_call_back"
  add_index "voters", ["campaign_id"], :name => "index_voters_on_campaign_id"
  add_index "voters", ["status"], :name => "index_voters_on_status"
  add_index "voters", ["voter_list_id"], :name => "index_voters_on_voter_list_id"

end
