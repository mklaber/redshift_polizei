namespace :db do
  desc 'Migrate the database'
  task :migrate do
    on roles(:db) do
      within release_path do
        with rack_env: fetch(:rack_env) do
          execute :bundle, :exec, :rake, 'db:migrate'
        end
      end
    end
  end
end
