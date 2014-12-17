set :environment_variable, 'RACK_ENV'

every :hour, :roles => [:app] do
  rake 'redshift:tablereport:update'
end

every :hour, :roles => [:app] do
  rake 'redshift:auditlog:import'
end
