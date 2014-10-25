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
  limit = 100
  offset = 0

  lists = VoterList.limit(limit).offset(offset)

  until lists.empty?
    lists.each do |list|
      list.voters.update_all(enabled: list.enabled)
    end

    offset += limit
    lists = VoterList.limit(limit).offset(offset)
  end
end

desc "Scrub voters w/ numbers in the DNC from the system (on a per account/campaign basis as it should:)"
task :scrub_lists_from_dnc => :environment do |t,args|
  voter_columns_to_import = Voter.columns.map(&:name)
  import_results = []
  not_found = []

  Campaign.includes(:account).find_in_batches(batch_size: 500) do |campaigns|
    campaigns.each do |campaign|
      campaign.account.blocked_numbers.for_campaign(campaign).find_in_batches(batch_size: 200) do |blocked_numbers|
        campaign.all_voters.where(phone: blocked_numbers.map(&:number)).find_in_batches(batch_size: 200) do |voters|
          voters_to_import  = []
          voters.each do |voter|
            blocked_number_id = blocked_numbers.detect{|n| n.number == voter.phone}.try(:id)
            if blocked_number_id
              voter.blocked_number_id = blocked_number_id
              voters_to_import << voter
            else
              not_found << [voter.account_id, voter.campaign_id, voter.id, voter.phone]
            end
          end
          import_results << Voter.import(voters_to_import, on_duplicate_key_update: [:blocked_number_id])
        end
      end
    end
  end

  print "Voters loaded from blocked_numbers but blocked_number could not be found when searching for ID\n"
  print "----------------------------------------------------------------------------------------------\n"
  print "Account ID, Campaign ID, Voter ID, Voter Phone\n"
  print not_found.map{|v| v.join(', ')}.join("\n")
  print "\n\n"

  print "Voter import results\n"
  print "----------------------------------------------------------------------------------------------\n"
  print "Success, Fail\n"
  print import_results.map{|r| "#{r.num_inserts}, #{r.failed_instances.size}"}.join("\n")
  print "\n\n"
end

desc "Inspect voter blocked ids"
task :inspect_voter_dnc => :environment do |t,args|
  x = Voter.where('blocked_number_id is not null').group(:campaign_id).count
  y = Voter.where('blocked_number_id is null').group(:campaign_id).count
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
