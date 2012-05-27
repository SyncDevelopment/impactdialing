desc "Update twilio call data" 

task :update_twilio_stats => :environment do
  CallAttempt.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus = 'completed')").find_in_batches(:batch_size => 10) do |attempts|
    attempts.each { |attempt| TwilioLib.new.update_twilio_stats_by_model attempt }
  end
  
  TransferAttempt.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus = 'completed')").find_in_batches(:batch_size => 10) do |transfer_attempts|
    transfer_attempts.each { |transfer_attempt| TwilioLib.new.update_twilio_stats_by_model transfer_attempt }
  end
  
  CallerSession.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus = 'completed')").find_in_batches(:batch_size => 10) do |sessions|
    sessions.each { |session| TwilioLib.new.update_twilio_stats_by_model session }
  end
end

task :destory_phantoms => :environment do
  # find calls with Twilio shows as ended but are still logged into our system
  phatom_callers = CallerSession.all(:conditions=>"on_call = 1 and tDuration is not NULL")
  phatom_callers.each do |phantom|
    phantom.end_running_call
    phantom.on_call=0
    phantom.save
    message="killed Phantom #{phantom.id} (#{phantom.campaign.name})"
    puts message
    Postoffice.deliver_feedback(message)
  end
end