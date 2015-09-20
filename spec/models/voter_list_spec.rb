require 'rails_helper'

describe VoterList, :type => :model do
  let(:valid_attrs) do
    {
      name: 'blah',
      s3path: '/somewhere/on/s3/blah.csv',
      csv_to_system_map: {'First Name' => 'first_name', 'Phone' => 'phone'},
      uploaded_file_name: 'blah.csv'
    }
  end
  it 'serializes #csv_to_system_map as JSON' do
    list = VoterList.create!(valid_attrs.merge(campaign: create(:preview)))
    expect(list.reload.csv_to_system_map).to eq valid_attrs[:csv_to_system_map]
  end

  describe 'csv_to_system_map restrictions' do
    let(:campaign){ create(:power) }
    let(:custom_id_mapping) do
      {
        'Phone' => 'phone',
        'ID' => 'custom_id'
      }
    end
    let(:voter_list) do
      build(:voter_list, {
        campaign: campaign,
        csv_to_system_map: custom_id_mapping
      })
    end

    context 'when this is the first list for the campaign' do
      it 'can map custom_id' do
        expect(voter_list).to be_valid
      end
    end
    context 'when first list for campaign did map custom id' do
      let(:second_voter_list) do
        build(:voter_list, {
          campaign: campaign,
          csv_to_system_map: custom_id_mapping
        })
      end
      let(:third_voter_list) do
        build(:voter_list, {
          campaign: campaign,
          csv_to_system_map: {
            'Phone' => 'phone'
          }
        })
      end
      before do
        voter_list.save!
      end
      it 'can map custom_id' do
        expect(second_voter_list).to be_valid
      end
      it 'is invalid if no custom id is mapped' do
        second_voter_list.save!
        third_voter_list.valid?
        expect(third_voter_list.errors[:csv_to_system_map]).to include I18n.t('activerecord.errors.models.voter_list.custom_id_map_required')
      end
    end
    context 'when first list for campaign did not map custom id' do
      let(:second_voter_list) do
        build(:voter_list, {
          campaign: campaign,
          csv_to_system_map: custom_id_mapping
        })
      end
      before do
        voter_list.csv_to_system_map = {
          'Phone' => 'phone'
        }
        voter_list.save!
      end
      it 'cannot map custom_id' do
        second_voter_list.valid?
        expect(second_voter_list.errors[:csv_to_system_map]).to include I18n.t('activerecord.errors.models.voter_list.custom_id_map_prohibited')
      end
    end
  end

  it "validates the uniqueness of name in a case insensitive manner" do
    user = create(:user)
    create(:voter_list, :name => 'same', :account => user.account)
    expect(build(:voter_list, :name => 'Same', :account => user.account)).to have(1).error_on(:name)
  end

  describe "valid file" do
    it "should consider csv file extension as valid" do
      expect(VoterList.valid_file?("abc.csv")).to be_truthy
    end
    it "should consider CSV file extension as valid" do
      expect(VoterList.valid_file?("abc.CSV")).to be_truthy
    end
    it "should consider txt file extension as valid" do
      expect(VoterList.valid_file?("abc.txt")).to be_truthy
    end
    it "should consider txt file extension as valid" do
      expect(VoterList.valid_file?("abc.txt")).to be_truthy
    end
    it "should consider null fileas invalid" do
      expect(VoterList.valid_file?(nil)).to be_falsey
    end
    it "should consider non csv txt file as invalid" do
      expect(VoterList.valid_file?("abc.psd")).to be_falsey
    end
  end

  describe "seperator from file extension" do
    it "should return , for csv file" do
      expect(VoterList.separator_from_file_extension("abc.csv")).to eq(',')
    end

    it "should return \t for txt file" do
      expect(VoterList.separator_from_file_extension("abc.txt")).to eq("\t")
    end
  end

  describe "voter enable callback after save" do
    it "should queue job to enable all members when list enabled" do
      voter_list         = create(:voter_list, enabled: false)
      voter          = create(:voter, :disabled, voter_list: voter_list)
      voter_list.enabled = true
      voter_list.save
      voter_list_change_job = {'class' => 'CallList::Jobs::ToggleActive', 'args' => [voter_list.id]}
      expect(resque_jobs(:import)).to include voter_list_change_job
    end

    it "should queue job to disable all members when list disabled" do
      voter_list         = create(:voter_list, enabled: true)
      voter              = create(:voter, :disabled, voter_list: voter_list)
      voter_list.enabled = false
      voter_list.save
      voter_list_change_job = {'class' => 'CallList::Jobs::ToggleActive', 'args' => [voter_list.id]}
      expect(resque_jobs(:import)).to include voter_list_change_job
    end
  end
end

# ## Schema Information
#
# Table name: `voter_lists`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`name`**                | `string(255)`      |
# **`account_id`**          | `integer`          |
# **`active`**              | `boolean`          | `default(TRUE)`
# **`created_at`**          | `datetime`         |
# **`updated_at`**          | `datetime`         |
# **`campaign_id`**         | `integer`          |
# **`enabled`**             | `boolean`          | `default(TRUE)`
# **`separator`**           | `string(255)`      |
# **`headers`**             | `text`             |
# **`csv_to_system_map`**   | `text`             |
# **`s3path`**              | `text`             |
# **`uploaded_file_name`**  | `string(255)`      |
# **`voters_count`**        | `integer`          | `default(0)`
# **`skip_wireless`**       | `boolean`          | `default(TRUE)`
# **`households_count`**    | `integer`          |
#
# ### Indexes
#
# * `index_voter_lists_on_user_id_and_name` (_unique_):
#     * **`account_id`**
#     * **`name`**
#
