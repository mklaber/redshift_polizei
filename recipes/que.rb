# Capistrano Recipes for managing que
#
# Add these callbacks to have the que process restart when the server
# is restarted:
#
#   after "deploy:stop",    "que:stop"
#   after "deploy:start",   "que:start"
#   after "deploy:restart", "que:restart"
#
# To change the number of workers define a Capistrano variable que_num_workers:
#
#   set :que_num_workers, 4
#
# If you've got que workers running on specific servers, you can also specify
# which servers have que running and should be restarted after deploy.
#
#   set :que_server_role, :worker
#

Capistrano::Configuration.instance.load do
  namespace :que do
    def env
      fetch(:env, false) ? "RACK_ENV=#{fetch(:env)}" : ''
    end

    def workers
      fetch(:que_num_workers, false) ? "QUE_WORKER_COUNT=#{fetch(:que_num_workers)}" : ''
    end

    def roles
      fetch(:que_server_role, :app)
    end

    def que_command
      fetch(:que_command, "bundle exec #{fetch(:current_path)}/scripts/que")
    end

    desc 'Stop the que process'
    task :stop, :roles => lambda { roles } do
      run "cd #{current_path};#{env} #{workers} #{que_command} stop"
    end

    desc 'Start the que process'
    task :start, :roles => lambda { roles } do
      run "cd #{current_path};#{env} #{workers} #{que_command} start"
    end

    desc 'Restart the que process'
    task :restart, :roles => lambda { roles } do
      run "cd #{current_path};#{env} #{workers} #{que_command} restart"
    end
  end
end
