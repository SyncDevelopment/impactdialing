class CallFlow::Web::Data
  attr_reader :script

private
  def util
    CallFlow::Web::Util
  end

  def fields(data)
    clean = util.filter(whitelist, data)
    if clean[:phone].nil?
      clean[:phone] = data[:phone]
    end
    clean
  end

  def custom_fields(data)
    util.filter(whitelist, data)
  end

  def contact_fields
    @contact_fields ||= CallFlow::Web::ContactFields.new(script)
  end

  def whitelist
    @whitelist ||= contact_fields.data
  end

  def whitelist_flags
    util.build_flags(whitelist)
  end

public
  def initialize(script)
    @script = script
  end

  def build(house)
    if house.present?
      members = house[:voters].map do |member|
        {
          fields:        fields(member[:fields]),
          custom_fields: custom_fields(member[:custom_fields])
        }
      end
      data = {
        phone: house[:phone],
        members: members
      }
    else
      data = {campaign_out_of_leads: true}
    end

    data
  end
end
