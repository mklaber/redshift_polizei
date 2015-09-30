namespace :deploy do
  task :restart do
    on roles(:app) do
      within release_path do
        execute :touch, "tmp/restart.txt"
      end
    end
  end
end
