require './app/main'

# set :output, "/path/to/my/cron_log.log"
report_update_frequency = 10.minutes

every report_update_frequency do
  renew_reports
end
