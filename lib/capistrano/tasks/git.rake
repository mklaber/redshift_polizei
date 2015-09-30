namespace :git do
  def current_env
    fetch(:rack_env)
  end

  desc "tag the deployment in git"
  task :tag_last_deploy do
    run_locally do
      user = capture(:git, "config --get user.name").chomp
      email = capture(:git, "config --get user.email").chomp
      timestamp = Time.now
      tag_name = "deployed_to_#{current_env}_from_branch_#{fetch :branch}_#{timestamp.localtime.strftime("%Y-%m-%d_%H-%M-%S")}"
      execute :git, %(tag -a -m "Tagging deploy to #{current_env} from branch '#{fetch :branch}' at #{timestamp} by #{user} <#{email}>" "#{tag_name}")
      execute :git, "push --tags origin"
      puts "Tagged release with #{tag_name}."
    end
  end

  after 'deploy:finished' , 'db:migrate'
end
