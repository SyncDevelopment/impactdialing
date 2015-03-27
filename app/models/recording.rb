require "paperclip"

class Recording < ActiveRecord::Base
  validates_presence_of :file_file_name, :message => "File can't be blank"
  validates_presence_of :name
  validate :validate_file_name
  belongs_to :account
  has_many :campaigns

  scope :active, -> { where(:active => true) }

  has_attached_file :file,
                    :storage => :s3,
                    :s3_credentials => Rails.root.join('config', 'amazon_s3.yml').to_s,
                    :s3_protocol => 'https',
                    :path => "/#{Settings.recording_env}/uploads/:account_id/:id.:extension"

  def validate_file_name
    if file_file_name.blank?
      errors.add(:file, "can't be blank")
    else
      extension = file_file_name.split(".").last
      if !['wav', 'mp3', 'aif', 'aiff', ].include?(extension)
        errors.add(:base, "Filetype #{extension} is not supported.  Please upload a file ending in .mp3, .wav, or .aiff")
      end
    end
  end
end

# ## Schema Information
#
# Table name: `recordings`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`account_id`**         | `integer`          |
# **`active`**             | `integer`          | `default(1)`
# **`name`**               | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
# **`file_file_name`**     | `string(255)`      |
# **`file_content_type`**  | `string(255)`      |
# **`file_file_size`**     | `string(255)`      |
# **`file_updated_at`**    | `datetime`         |
#
