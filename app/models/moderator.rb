class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  belongs_to :account
  
  scope :active, :conditions => {:active => true}
  
  def switch_monitor_mode(caller_session, type)
    conference_sid = get_conference_id(caller_session)
    if type == "breakin"
      Twilio::Conference.unmute_participant(conference_sid, call_sid)
    else
      Twilio::Conference.mute_participant(conference_sid, call_sid)
    end
  end
  
  def stop_monitoring(caller_session)
    conference_sid = get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Conference.kick_participant(conference_sid, call_sid)
  end
  
  def self.caller_connected_to_campaign(caller, campaign, caller_session)
    caller.email = caller.name if caller.is_phones_only?
    caller_info = caller.info
    data = caller_info.merge(:campaign_name => campaign.name, :session_id => caller_session.id, :campaign_fields => {:id => campaign.id, :callers_logged_in => campaign.caller_sessions.on_call.length+1,
       :voters_count => campaign.voters_count("not called", false).length, :dials_in_progress => campaign.call_attempts.not_wrapped_up.length })
    caller.account.moderators.active.each {|moderator| Pusher[moderator.session].trigger('caller_session_started', data)}    
  end
  
  def self.publish_event(campaign, event, data)
    campaign.account.moderators.active.each {|moderator| Pusher[moderator.session].trigger(event, data)}
  end
  
  def get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    conferences = Twilio::Conference.list({"FriendlyName" => caller_session.session_key})
    confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
    conference_sid = ""
    conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
  end
  
end
