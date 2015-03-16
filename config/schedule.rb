set :environment_variable, 'RACK_ENV'

every :hour, :roles => [:app] do
  rake 'redshift:tablereports:update'
end

every :hour, :roles => [:app] do
  rake 'redshift:auditlog:import'
end
