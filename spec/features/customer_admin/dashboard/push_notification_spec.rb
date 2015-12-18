require 'acceptance_helper'

def within_nth_campaign_cell(row_n, cell_n, &block)
  within "#campaigns-monitor tbody tr:nth-of-type(#{row_n}) td:nth-of-type(#{cell_n})" do
    yield
  end
end

def within_nth_caller_cell(row_n, cell_n, &block)
  within "#callers-monitor tbody tr:nth-of-type(#{row_n}) td:nth-of-type(#{cell_n})" do
    yield
  end
end

describe 'Client Web Dashboard (/client/index)', type: :feature, admin: true do
  let(:auth_time){ Time.now }
  let(:user) do
    create(:user)
  end
  let(:account) do
    user.account
  end
  before do
    web_login_as(user)
  end

  context 'when a user is logged in' do
    it 'should be able to turn on Call Recording' do
      visit client_root_path

      click_on 'Turn call recording on'

      expect(page).to have_content 'Call recording turned on.'
    end

    it 'should be able to turn off Call Recording' do
      account = User.last.account
      account.record_calls = true
      account.save!
      visit client_root_path

      click_on 'Turn call recording off'

      expect(page).to have_content 'Call recording turned off.'
    end




          #
          # let(:power_no_calls) do
          #   create(:power, {
          #     account: account,
          #     start_time: auth_time,
          #     end_time: auth_time
          #   })
          # end
          #
          # let(:power_extra) do
          #   create(:power, {
          #     account: account,
          #     start_time: auth_time,
          #     end_time: auth_time
          #   })
          # end
          #
          #
          #
          # let(:extra_callers) do
          #   create_list(:caller, 3, {
          #     account: account,
          #     campaign: power_extra
          #   })
          # end
          #
          # before do
          #   redis_states = ['On call', 'On call', 'On hold']
          #   3.times do |i|
          #     session = create(:webui_caller_session, {
          #       caller: callers[i],
          #       campaign: power_campaign,
          #       on_call: true,
          #       available_for_call: redis_states[i] == 'On call' ? false : true
          #     })
          #
          #     c = power_campaign
          #     redis_status_set_state(c, redis_states[i], session)
          #   end
          #
          #   2.times do |i|
          #     session = create(:webui_caller_session, {
          #       caller: extra_callers[i],
          #       campaign: power_extra,
          #       on_call: true,
          #       available_for_call: i == 0 ? true : false
          #     })
          #
          #     c = power_extra
          #     redis_status_set_state(c, 'On hold', session)
          #   end
          #
          #   visit client_root_path
          # end

    describe 'listing active campaigns and callers', js: true do

      let(:power_campaign) do
        create(:power, {
          account: account,
          start_time: auth_time,
          end_time: auth_time
        })
      end

      let(:params) do {
        "account_sid" => 'ac123',
        "sid" => UUID.new.generate,
      }
      end

      let(:callers) do
        create_list(:caller, 6, {
          account: account,
          campaign: power_campaign
        })
        Caller.where(1).to_a
      end

      before do
        CallFlow::Web::Event.enable!
        session = create(:webui_caller_session, {
          caller:callers[0],
          campaign: power_campaign,
          on_call: true,
          sid: params["sid"],
          # available_for_call: redis_states[i] == 'On call' ? false : true,
        })

        # caller_session = power_campaign.caller_sessions.create!({
        #   caller_id: caller[0],
        #   on_call: true,
        #   sid: params["sid"]
        # })
      end

      context 'Active Campaigns' do
        it 'only lists campaigns w/ active callers logged in' do
          within '#campaigns-monitor' do
            visit client_root_path
            save_and_open_page
            # sleep(15)
            puts page.evaluate_script("window.Bunker=Pusher.instances[0].subscribe(channelName)")
            puts page.evaluate_script("window.Bunker.bind('caller_session.created', function(){ alert('Bunker!')})")
            puts page.evaluate_script

            CallFlow::CallerSession.create(params)

            p "doda: #{CallFlow::Web::Event.enabled?}"
            puts "Running assertion"


            # sleep(15)
            expect(page).to have_content power_campaign.name
            # expect(page).not_to have_content power_no_calls.name
          end
        end
        it 'lists the number of callers logged in for the specified campaign' do
          within_nth_campaign_cell 2, 2 do
            expect(page).to have_content power_campaign.caller_sessions.count
          end
        end
        it 'lists the number of callers on call' do
          within_nth_campaign_cell 2, 3 do
            expect(page).to have_content 2
          end
        end
        it 'lists the number of callers in wrap up' do
          within_nth_campaign_cell 2, 4 do
            expect(page).to have_content 0
          end
        end
        it 'lists the number of callers on hold' do
          within_nth_campaign_cell 2, 5 do
            expect(page).to have_content 1
          end
        end
        it 'lists the number of ringing lines'
        it 'lists the number of numbers remaining in the call list'
      end

      context 'Active Callers' do
        it 'lists the caller email address' do
          within_nth_caller_cell 2, 1 do
            expect(page).to have_content callers.first.username
          end
        end
        it 'displays the campaign the caller is logged in for in a drop down menu' do
          within_nth_caller_cell 2, 2 do
            expect(page.find("select.reassign-campaign option[value='#{power_campaign.id}']")).to be_selected
          end
        end
        it 'lists the calls status e.g. on hold' do
          within_nth_caller_cell 2, 3 do
            expect(page).to have_content 'On call'
          end
        end
        it 'lists the time the call has been in the current status' do
          within_nth_caller_cell 2, 4 do
            expect(page.body).to match(/\d\d:\d\d:\d\d/)
          end
        end
      end
    end
  end
end