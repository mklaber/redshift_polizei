require './app/main'

every :day, :at => '12pm', :roles => [:app] do
  rake 'redshift:tablereport:update'
end

every :hour, :roles => [:app] do
  rake 'redshift:auditlog:import'
end
