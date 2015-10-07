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

  desc "asks the user what branch to deploy to or use the default_branch"
  task :ask_branch do
    # Fetches the current branch
    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp

    # Will be changed only if necessary
    set :branch, fetch(:default_branch)

    if current_branch != fetch(:default_branch)
      # Asks the user what branch to use
      set :user_choice, ask("the branch to use\n", "'c' or 'current' for #{current_branch}, anything else will use #{fetch :default_branch}")

      if fetch(:user_choice) == 'c' || fetch(:user_choice) == 'current'
        set :branch, current_branch
      end
    end

    puts "\n> Deploying from branch '#{fetch :branch}'\n\n"
  end
end
