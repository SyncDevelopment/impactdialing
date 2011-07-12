class RoboRecording < ActiveRecord::Base
  include ActionController::UrlWriter

  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => "#{RAILS_ROOT}/config/amazon_s3.yml",
                    :path=>"/:filename"
  belongs_to :script
  has_many :recording_responses
  accepts_nested_attributes_for :recording_responses, :allow_destroy => true
  before_post_process :set_content_type

  validates_presence_of :name, :message => "Please name your recording."
  validates_attachment_content_type :file, :content_type => ['audio/mpeg', 'audio/wav', 'audio/wave', 'audio/x-wav', 'audio/aiff', 'audio/x-aifc', 'audio/x-aiff', 'audio/x-gsm', 'audio/gsm', 'audio/ulaw']

  def set_content_type
    self.file.instance_write(:content_type, MIME::Types.type_for(self.file_file_name).to_s)
  end

  def next
    self.script.robo_recordings.find(:first, :conditions => ["id > ?", self.id]) || OpenStruct.new(:twilio_xml => hangup)
  end


  def response_for(digits)
    self.recording_responses.find_by_keypad(digits)
  end

  def twilio_xml(call_attempt)
    ivr_url = call_attempts_url(:host => HOST, :id => call_attempt.id, :robo_recording_id => self.id)
    self.recording_responses.count > 0 ? ivr_prompt(ivr_url) : play_message
  end

  def hangup
    Twilio::Verb.new { |v| v.hangup }.response
  end

  private

  def play_message
    Twilio::Verb.new { |v| v.play URI.escape(self.file.url) }.response
  end

  def ivr_prompt(ivr_url)
    verb = Twilio::Verb.new do |v|
      3.times do
        v.gather(:numDigits => 1, :timeout => 10, :action => ivr_url, :method => "POST") do
          v.play URI.escape(self.file.url)
        end
      end
    end
    verb.response
  end

end
