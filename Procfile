web:  bundle exec rails server thin -p $PORT 
resque_dialer: bundle exec ruby lib/resque_predictive_dialer.rb
new_simulator: bundle exec ruby simulator/newest_simulator.rb
email_worker_job: rake environment resque:work QUEUE=email_worker_job
voter_list_upload_worker_job: rake environment resque:work QUEUE=voter_list_upload_worker_job
report_download_worker_job: rake environment resque:work QUEUE=report_download_worker_job
background_worker_job: rake environment resque:work QUEUE=background_worker_job
answered_worker_job: rake environment resque:work QUEUE=answered_worker_job
clock:   rake environment resque:scheduler
dialer_worker: rake environment resque:work QUEUE=dialer_worker MINUTES_PER_FORK=20
calculate_dials_worker: rake environment resque:work QUEUE=calculate_dials_worker MINUTES_PER_FORK=20
simulator_worker: rake environment resque:work QUEUE=simulator 
debit_worker_job: rake environment resque:work QUEUE=debit_worker_job

