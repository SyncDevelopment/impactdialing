## Example script to pull recordings for given list of phone numbers
#
# account = Account.find xxx
# phone_numbers = ['xxx','yyy']
# voters = account.voters.where(phone: phone_numbers)
# out = ''
# voters.each do |v|
#   out << "#{v.phone}\n"
#   call_attempts = v.call_attempts.where('recording_url is not null').order('voter_id DESC')
#   call_attempts.each do |ca|
#     out << "- #{ca.tStartTime.strftime('%m/%d/%Y at %I:%M%P')} #{ca.recording_url}\n"
#   end
# end
# print out

desc "Migrate Voter#voicemail_history to CallAttempt#recording_id & #recording_delivered_manually"
task :migrate_voicemail_history => :environment do
  voters = Voter.includes(:call_attempts).where('status != "not called"').where('voicemail_history is not null')

  dirty = []
  voters.each do |voter|
    call_attempt = voter.call_attempts.first
    recording_id = voter.voicemail_history.split(',').first

    call_attempt.recording_id = recording_id
    call_attempt.recording_delivered_manually = false
    dirty << call_attempt
  end

  puts CallAttempt.import(dirty, {
      :on_duplicate_key_update => [:recording_id, :recording_delivered_manually]
  })
end

desc "sync Voters#enabled w/ VoterList#enabled"
task :sync_all_voter_lists_to_voter => :environment do |t, args|
  limit  = 100
  offset = 0
  lists  = VoterList.limit(limit).offset(offset)
  rows   = []

  until lists.empty?
    print "#{1 + offset} - #{offset + limit}\n"
    lists.each do |list|
      row = []
      row << list.id
      if list.enabled?
        row << list.voters.count - list.voters.enabled.count
        row << 0
      else
        row << 0
        row << list.voters.count - list.voters.disabled.count
      end
      bits = []
      bits << :list if list.enabled?
      blocked_bit     = Voter.bitmask_for_enabled(*[bits + [:blocked]].flatten)
      not_blocked_bit = Voter.bitmask_for_enabled(*bits)

      list.voters.blocked.update_all(enabled: blocked_bit)
      list.voters.not_blocked.update_all(enabled: not_blocked_bit)
      if list.enabled?
        row << list.voters.enabled.count
        row << 0
      else
        row << 0
        row << list.voters.disabled.count
      end

      rows << row
    end

    offset += limit
    lists = VoterList.limit(limit).offset(offset)
  end
  print "List ID, Enabling, Disabling, Total enabled, Total disabled\n"
  print rows.map{|row| row.join(", ")}.join("\n") + "\n"
  print "done\n"
end

desc "Migrate Voter#blocked_number_id values to Voter#blocked bool flags"
task :migrate_voter_blocked_number_id_to_enabled_bitmask => :environment do |t, args|
  print "#{Voter.with_exact_enabled(:blocked).count} blocked/disabled voters\n"
  print "#{Voter.with_exact_enabled(:list, :blocked).count} blocked/enabled voters\n"

  enabled          = Voter.where(enabled: 1).where('blocked_number_id IS NOT NULL AND blocked_number_id > 0')
  enabled_bitmask  = Voter.bitmask_for_enabled(:list, :blocked)
  disabled         = Voter.where(enabled: 0).where('blocked_number_id IS NOT NULL AND blocked_number_id > 0')
  disabled_bitmask = Voter.bitmask_for_enabled(:blocked)
  untouched        = Voter.where('blocked_number_id IS NULL OR blocked_number_id = 0')
  
  print "Blocking #{enabled.count} enabled w/ bitmask #{enabled_bitmask}...\n"
  enabled.update_all(enabled: enabled_bitmask)
  print "Blocked #{Voter.with_exact_enabled(:list, :blocked).count} voters\n"
  print "Blocking #{disabled.count} disabled Voters w/ bitmask #{disabled_bitmask}...\n"
  disabled.update_all(enabled: disabled_bitmask)
  print "Blocked #{Voter.with_exact_enabled(:blocked).count} voters\n"
  print "Left #{untouched.count} voters untouched because they're not blocked...\n"
end

desc "Fix-up DNC for Account 895"
task :fix_up_account_895 => :environment do |t,args|
  account        = Account.find 895
  tmp_campaign   = account.campaigns.find 4465
  reg_campaign   = account.campaigns.find 4388
  account.blocked_numbers.for_campaign(tmp_campaign).update_all(campaign_id: reg_campaign.id)

  blocked_numbers = account.blocked_numbers.for_campaign(reg_campaign)
  blocked_voters  = reg_campaign.all_voters.where(phone: blocked_numbers.map(&:number))

  blocked_voters.enabled.update_all(enabled: Voter.bitmask_for_enabled(:list, :blocked))
  blocked_voters.disabled.update_all(enabled: Voter.bitmask_for_enabled(:blocked))
end

desc "Inspect voter blocked ids"
task :inspect_voter_dnc => :environment do |t,args|
  x = Voter.with_enabled(:blocked).group(:campaign_id).count
  y = Voter.without_enabled(:blocked).group(:campaign_id).count
  print "Blocked: #{x}\n"
  print "Not blocked: #{y}\n"
end

desc "De-duplicate BlockedNumber records"
task :dedup_blocked_numbers => :environment do |t,args|
  dup_numbers = BlockedNumber.group(:account_id, :campaign_id, :number).count.reject{|k,v| v < 2}
  dup_numbers.each do |tuple, count|
    account_id  = tuple[0]
    campaign_id = tuple[1]
    number      = tuple[2]
    
    raise ArgumentError, "Bad Data... Account[#{account_id}] Campaign[#{campaign_id}] Count[#{count}]" if account_id.blank? or count == 1

    duplicate_ids = BlockedNumber.where(account_id: account_id, campaign_id: campaign_id, number: number).limit(count-1).pluck(:id)
    to_delete     = BlockedNumber.where(id: duplicate_ids)
    deleted       = to_delete.map{|n| {account_id: n.account_id, campaign_id: n.campaign_id, number: n.number}}.to_json
    to_delete.delete_all

    print "Deleted #{deleted.size} BlockedNumber records (as JSON):\n#{deleted}\n"
  end
end

desc "Inspect duplicate BlockedNumber entries"
task :inspect_dup_blocked_numbers => :environment do |t,args|
  dup_numbers = BlockedNumber.group(:account_id, :campaign_id, :number).count.reject{|k,v| v < 2}
  print "Account ID, Campaign ID, Number, Count\n"
  dup_numbers.each do |tuple, count|
    print tuple.join(',') + ", #{count}\n"
  end
  print "\n"
end

desc "Update VoterList voters_count cache"
task :update_voter_list_voters_count_cache => :environment do |t,args|
  VoterList.select([:id, :campaign_id]).find_in_batches do |voter_lists|
    voter_lists.each do |voter_list|
      VoterList.reset_counters(voter_list.id, :voters)
    end
  end
end

desc "Refresh Redis Wireless Block List & Wireless <-> Wired Ported Lists"
task :refresh_wireless_ported_lists => :environment do |t,args|
  DoNotCall::Jobs::RefreshWirelessBlockList.perform('nalennd_block.csv')
  DoNotCall::Jobs::RefreshPortedLists.perform
end

desc "Fix pre-existing VoterList#skip_wireless values"
task :fix_pre_existing_list_skip_wireless => :environment do
  # lists that were never scrubbed => < 2014-10-29
  # lists that were never scrubbed => > 2014-10-29 11:15am < 2014-10-29 12:00pm
  # lists that were scrubbed => > 2014-10-29 3am < 2014-10-29 11:15am
  # lists that were scrubbed => > 2014-10-29 12pm
  never_scrubbed = VoterList.where('created_at <= ? OR (created_at >= ? AND created_at <= ?)',
    '2014-10-29 07:00:00 0000',
    '2014-10-29 18:15:00 0000',
    '2014-10-29 19:15:00 0000')
  never_scrubbed.update_all(skip_wireless: false)
end

desc "Read phone numbers from csv file and output as array."
task :extract_numbers, [:filepath, :account_id, :campaign_id, :target_column_index] => :environment do |t, args|
  raise "Do Not Do This. BlockedNumber.import will bypass after create hooks, breaking the dialer because then blocked numbers could be dialed."
  require 'csv'

  account_id = args[:account_id]
  campaign_id = args[:campaign_id]
  target_column_index = args[:target_column_index].to_i
  filepath = args[:filepath]
  numbers = []

  CSV.foreach(File.join(Rails.root, filepath)) do |row|
    numbers << row[target_column_index]
  end

  print "\n"
  numbers.shift # lose the header
  print "numbers = #{numbers.compact}\n"
  print "account = Account.find(#{account_id})\n"
  if campaign_id.present?
    print "campaign = account.campaigns.find(#{campaign_id})\n"
    print "columns = [:account_id, :campaign_id, :number]\n"
    print "values = numbers.map{|number| [account.id, campaign.id, number]}\n"
  else
    print "columns = [:account_id, :number]\n"
    print "values = numbers.map{|number| [account.id, number]}\n"
  end
  print "BlockedNumber.import columns, values\n"
  print "\n"
end

desc "Generate / append to CHANGELOG.md entries within the start_date and end_date"
task :changelog, [:after, :before] do |t, args|
  desired_entries = [
    'changelog',
    'closes',
    'fixes',
    'completes',
    'delivers',
    '#'
  ]
  format = 'format:"%cr%n-----------%n%s%+b%n========================================================================"'
  after = args[:after]
  before = args[:before]
  cmd = 'git log'
  cmd << " --pretty=#{format}"
  desired_entries.each do |de|
    cmd << " --grep='#{de}'"
  end
  cmd << " --after='#{after}'" unless after.blank?
  cmd << " --before='#{before}'" unless before.blank?
  print cmd + "\n"
end

desc "Generate CSV of random, known bad numbers w/ a realistic distribution (eg 2-4 members per household & 85-95%% unique numbers)"
task :generate_realistic_voter_list => :environment do
  require 'forgery'

  today    = Date.today
  
  4.times do |i|
    filepath = File.join(Rails.root, 'tmp', "#{today.year}-#{today.month}-#{today.day}-#{Forgery(:basic).number}-random-part(#{i+1}).csv")
    file     = File.new(filepath, 'w+')
    file << "#{['VANID', 'Phone', 'Last Name', 'First Name', 'Suffix', 'Sex', 'Age', 'Party'].join(',')}\n"
    250_000.times do
    # 5.times do
      row = [
        Forgery(:basic).number(at_least: 1000, at_most: 999999),
        "1#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}#{Forgery(:basic).number(at_least: 0, at_most: 9)}",
        Forgery(:name).last_name,
        Forgery(:name).first_name,
        Forgery(:name).suffix,
        %w(Male Female).sample,
        Forgery(:basic).number,
        %w(Republican Democrat Independent).sample
      ]
      file << "#{row.join(',')}\n"
    end
    file.close
  end
end
