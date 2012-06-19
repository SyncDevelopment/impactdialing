require Rails.root.join("jobs/heroku_resque_auto_scale")
class ResetPasswordEmailJob
  extend ::HerokuResqueAutoScale
  @queue = :worker_job
  
  
  def self.perform(user_id)
    user = User.find(user_id)
    user_mailer = UserMailer.new
    user_mailer.reset_password(user)
  end
  
end