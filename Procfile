web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb

dialer_loop: bundle exec ruby lib/dialer_loop.rb
simulator_loop: bundle exec ruby simulator/simulator_loop.rb

dialer_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=dialer_worker

simulator_worker: rake environment TERM_CHILD=1 RESQUE_TERM_TIMEOUT=10 resque:work QUEUE=simulator_worker

upload_download: rake environment resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=5 QUEUE=upload_download

background_worker: rake environment resque:work QUEUE=background_worker

alert_worker: rake environment resque:work QUEUE=alert_worker

call_flow: bundle exec sidekiq -c 8 -q call_flow LIBRATO_AUTORUN=1

persist_worker: rake environment resque:work QUEUE=persist_jobs

twilio_stats: rake environment resque:work QUEUE=twilio_stats

clock: rake environment resque:scheduler VERBOSE=true

app_health: rake environment monitor_app_health APP_HEALTH_RUN_INTERVAL=90
