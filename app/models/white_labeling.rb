module WhiteLabeling
  ['title', 'full_title', 'phone', 'email', ].each do |value|
    define_method("white_labeled_#{value}") do |domain|
      I18n.t("white_labeling.#{correct_domain(domain)}.#{value}")
    end
  end

  def correct_domain(domain)
    domain = 'localhost' unless domain
    d = domain.downcase.gsub(/\..+$/, '')
    if I18n.t("white_labeling.#{d}", :default => '').blank?
      'impactdialing'
    else
      d
    end
  end
end
