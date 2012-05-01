module CallerEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
            
    def publish_start_calling
      publish_sync('start_calling', {caller_session_id: id}) if state == 'initial'                     
    end    
    
    def publish_caller_conference_started
      EM.run {
        unless caller.is_phones_only? 
          event_hash = campaign.caller_conference_started_event     
          caller_deferrable = Pusher[session_key].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
          caller_deferrable.callback {}
          caller_deferrable.errback { |error| }
        end
        campaign.account.moderators.last_hour.active.each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  id, campaign_id:  campaign.id, caller_id:  caller.id, call_status: attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {}
          moderator_deferrable.errback { |error| }          
        end              
      }   
    end
    
    def publish_calling_voter
      publish_async('calling_voter', {}) unless caller.is_phones_only?
    end
    
    def publish_caller_disconnected      
      publish_async("caller_disconnected",{}) unless caller.is_phones_only?
    end   
    
    
    def publish_moderator_caller_reassigned_to_campaign(old_campaign)
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, "caller_re_assigned_to_campaign", {:caller_session_id => id, :caller_id => caller.id, :campaign_fields => {:id => campaign.id, :campaign_name => campaign.name, :callers_logged_in => campaign.caller_sessions.on_call.size,
        :voters_count => Voter.remaining_voters_count_for('campaign_id', campaign.id), :dials_in_progress => campaign.call_attempts.not_wrapped_up.size }, :old_campaign_id => old_campaign.id,:no_of_callers_logged_in_old_campaign => old_campaign.caller_sessions.on_call.size})          
    end
    
    def publish_moderator_caller_disconnected
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
        :no_of_callers_logged_in => campaign.caller_sessions.on_call.size})      
    end
    
    def publish_moderator_conference_started
      EM.run {
        campaign.account.moderators.last_hour.active.each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {}
          moderator_deferrable.errback { |error| }          
        end              
      }   
      
    end
    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end