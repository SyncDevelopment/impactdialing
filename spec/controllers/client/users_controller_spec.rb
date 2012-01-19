require "spec_helper"

describe Client::UsersController do
  before(:each) do
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  it "resets a user's password" do
    user = Factory(:user)
    user.create_reset_code!
    get :reset_password, :reset_code => user.password_reset_code
    flash[:error].should be_blank
    assigns(:user).should == user
  end

  it "updates the password" do
    user = Factory(:user)
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => user.password_reset_code, :password => 'new_password'
    flash[:error].should be_blank
    User.authenticate(user.email, 'new_password').should == user
    user.reload.password_reset_code.should be_nil
  end

  it "does not change the password if the reset code is invalid" do
    user = Factory(:user, :new_password => 'xyzzy')
    user.create_reset_code!
    put :update_password, :user_id => user.id, :reset_code => 'xyz', :password => 'new_password'
    User.authenticate(user.email, 'new_password').should_not == user
    user.reload.password_reset_code.should_not be_nil
    user.authenticate_with?("xyzzy").should be_true
    flash[:error].should_not be_blank
  end

  it "invites a new user to the current user's account" do
    user = Factory(:user).tap{|u| login_as u}
    mailer = mock(UserMailer)
    UserMailer.stub(:new).and_return(mailer)
    mailer.should_receive(:deliver_invitation).with(anything, user)
    lambda {
      post :invite, :email => 'foo@bar.com'
    }.should change(user.account.users.reload, :count).by(1)
    user.account.users.reload.last.email.should == 'foo@bar.com'
    response.should redirect_to(:back)
  end

  describe 'destroy' do
    it "deletes a different user" do
      account = Factory(:account)
      user = Factory(:user, :email => 'foo@bar.com', :account => account)
      current_user = Factory(:user, :account => account).tap{|u| login_as u}
      post :destroy, :id => user.id
      User.find_by_id(user.id).should_not be
      response.should redirect_to(:back)
      flash[:notice].should == ['foo@bar.com was deleted']
    end

    it "doesn't delete the logged in user" do
      account = Factory(:account)
      user = Factory(:user, :email => 'foo@bar.com', :account => account)
      login_as user
      post :destroy, :id => user.id
      User.find_by_id(user.id).should be
      response.should redirect_to(:back)
      flash[:error].should == ["You can't delete yourself"]
    end
  end
end
