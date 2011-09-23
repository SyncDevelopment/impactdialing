# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include WhiteLabeling

  def cms(key)
    s = Seo.find_by_crmkey_and_active_and_version(key, 1, session[:seo_version])
    s = Seo.find_by_crmkey_and_active_and_version(key, 1, nil) if s.blank?

    if s.blank?
      ""
    else
      s.content
    end
  end

  def float_sidebar
    @floatSidebar="<script>
    $('content').style.float='right';
    $('sidebar').style.float='left';

      var obj = document.getElementById('sidebar');
      if (obj.style.styleFloat) {
          obj.style.styleFloat = 'left';
      } else {
          obj.style.cssFloat = 'left';
      }

      var obj = document.getElementById('content');
      if (obj.style.styleFloat) {
          obj.style.styleFloat = 'right';
      } else {
          obj.style.cssFloat = 'right';
      }

      </script>";
      ""
  end

  def send_rt(channel, key, post_data)
    require 'pusher'
    Pusher.app_id = PUSHER_APP_ID
    Pusher.key = PUSHER_KEY
    Pusher.secret = PUSHER_SECRET
    Pusher[channel].trigger(key, post_data)
    logger.info "SENT RT #{key} #{post_data} #{channel}"
  end

  def send_rt_old(key, post_data)
    # msg_url="https://#{TWILIO_AUTH}:x@#{TWILIO_ACCOUNT}.twiliort.com/#{key}"
    http = Net::HTTP.new("#{TWILIO_ACCOUNT}.twiliort.com", 443)
    req = Net::HTTP::Post.new("/#{key}")
    http.use_ssl = true
    req.basic_auth TWILIO_AUTH, "x"
    req.set_form_data(post_data, ';')
    response = http.request(req)
    logger.info "SENT RT #{key} #{post_data}: #{response.body}"
    return response.body
  end

  def hash_from_voter_and_script(script,voter)
    publish_hash={:id=>voter.id, :classname=>voter.class.to_s}
    #    publish_hash={:id=>voter.id}
    if !script.voter_fields.nil?
      fields = JSON.parse(script.voter_fields)
      fields.each do |field|
        #        logger.info "field: #{field}"
        if voter.has_attribute?(field)
          publish_hash[field] = voter.get_attribute(field)
        else
          logger.info "FAMILY ERROR could not find #{field}  in #{voter.id}"
        end
      end
    end
    publish_hash
  end

  def client_controller?(controllerName)
    ['client/accounts', 'client', 'voter_lists', 'monitor', 'client/campaigns', 'client/scripts', 'client/callers', 'client/reports', 'campaigns', 'scripts', 'broadcast', 'reports', 'home', ].include?(controllerName)
  end

  ['title', 'full_title', 'phone', 'email', ].each do |value|
    define_method("white_labeled_#{value}") do
      send(value, request.domain)
    end
  end

  def link_to_remove_fields(name, f, opts = {})
    f.hidden_field(:_destroy) + link_to_function(name, "remove_fields(this)", opts)
  end

  def link_to_add_fields(name, f, association, opts = {})
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, h("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"), opts)
  end

  def button_tag(value, opts = {})
    content_tag :button, value, { :type => :submit }.merge(opts)
  end
end
