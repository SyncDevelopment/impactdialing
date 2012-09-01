Factory.sequence :email do |n|
  "user#{n}@example.com"
end

Factory.sequence :name do |n|
  "user#{n}"
end

Factory.sequence :phonenumber do |n|
  "#{(10**10)+n}"
end

Factory.define :account do end

Factory.define :user do |u|
  u.account { Factory(:account) }
  u.email { Factory.next(:email) }
  u.new_password 'password'
  u.role "admin"
end

Factory.define :admin_user, :parent => :user do |u|
  u.email 'michael@impactdialing.com'
end

Factory.define :billing_account do |b|
end

Factory.define :script do |s|
  s.name 'a script'
end

Factory.define :campaign do |c|
  c.name 'a campaign'
  c.caller_id '1234567890'
  c.account { Factory(:account) }
  c.recycle_rate 1
  c.start_time (Time.now - 6.hours)
  c.end_time (Time.now - 7.hours)
  c.time_zone "Pacific Time (US & Canada)"
  c.script_id {Factory(:script).id}
  c.type 'Preview'
end

Factory.define :predictive do |c|
  c.name 'a campaign'
  c.caller_id '1234567890'
  c.account { Factory(:account) }
  c.recycle_rate 1
  c.start_time (Time.now - 6.hours)
  c.end_time (Time.now - 7.hours)
  c.time_zone "Pacific Time (US & Canada)"
  c.script_id {Factory(:script).id}
end

Factory.define :preview do |c|
  c.name 'a campaign'
  c.caller_id '1234567890'
  c.account { Factory(:account) }
  c.recycle_rate 1
  c.start_time (Time.now - 6.hours)
  c.end_time (Time.now - 7.hours)
  c.time_zone "Pacific Time (US & Canada)"
  c.script_id {Factory(:script).id}
end

Factory.define :progressive do |c|
  c.name 'a campaign'
  c.caller_id '1234567890'
  c.account { Factory(:account) }
  c.recycle_rate 1
  c.start_time (Time.now - 6.hours)
  c.end_time (Time.now - 7.hours)
  c.time_zone "Pacific Time (US & Canada)"
  c.script_id {Factory(:script).id}
end

Factory.define :robo do |c|
  c.name 'a campaign'
  c.caller_id '1234567890'
  c.account { Factory(:account) }
  c.recycle_rate 1
  c.start_time (Time.now - 6.hours)
  c.end_time (Time.now - 7.hours)
  c.time_zone "Pacific Time (US & Canada)"
  c.script_id {Factory(:script).id}
end



Factory.define :caller do |s|
  s.email { Factory.next(:email) }
  s.name 'a caller'
  s.campaign_id { Factory(:campaign).id }
end

Factory.define :voter_list do |v|
  v.enabled { true }
  v.campaign_id { Factory(:campaign).id }
  v.name { Factory.next(:name) }
  v.account { Factory(:account) }
end

Factory.define :voter do |v|
  v.FirstName { Factory.next(:name) }
  v.Phone { Factory.next(:phonenumber) }
  v.voter_list { Factory(:voter_list, :enabled => true) }
end

Factory.define :family do |v|
  v.FirstName { Factory.next(:name) }
  v.Phone { Factory.next(:phonenumber) }
end

Factory.define :caller_session do |s|
  s.campaign { Factory(:campaign, :account => Factory(:account)) }
  s.caller_id { Factory(:caller).id }
end

Factory.define :webui_caller_session do |wcs|
end

Factory.define :phones_only_caller_session do |wcs|
end


Factory.define :caller_identity do |s|
  s.caller_id { Factory(:caller).id }
end


Factory.define :call_attempt do |ca|
  ca.campaign { Factory(:campaign) }
  ca.caller { Factory(:caller) }
end

Factory.define :robo_recording do |rr|
  rr.name { Factory.next(:name) }
end

Factory.define :recording_response do |rr|
  rr.response 'response'
  rr.keypad '1'
end

Factory.define :call_response do |cr|
end

Factory.define :recording do |r|
  r.name 'name'
  r.file_file_name 'foo.mp3'
end

Factory.define :custom_voter_field do |cvf|
  cvf.name 'name'
end

Factory.define :custom_voter_field_value do |cvfv|
end

Factory.define :blocked_number do |b|
  b.account_id { Factory(:account).id }
  b.number '1234567890'
end

Factory.define :question do |q|
  q.text "question text"
  q.script_order '1'
  q.script {Factory(:script)}
end

Factory.define :possible_response do |pr|
  pr.value "no_response"
  pr.possible_response_order '1'
  pr.question {Factory(:question)}
end

Factory.define :answer do |a|
  a.caller { Factory(:caller) }
  pr = Factory(:possible_response)
  a.possible_response pr
  a.question pr.question
end

Factory.define :caller_campaign do |cc|
end

Factory.define :note do |n|
  n.note 'here is a note'
  n.script {Factory :script}
  n.script_order '1'
end

Factory.define :note_response do |n|
end


Factory.define :moderator do |n|
end

Factory.define :simulated_values do |sv|
end

Factory.define :transfer do |t|
end
Factory.define :transfer_attempt do |t|
end

Factory.define :call do |c|
end

Factory.define :payment do |c|
end



