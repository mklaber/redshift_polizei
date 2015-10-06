namespace :assets do
  desc 'Migrate the database'
  task :precompile do
    on roles(:db) do
      within release_path do
        with rack_env: fetch(:rack_env) do
          execute :bundle, :exec, :rake, 'assetpack:build'
        end
      end
    end
  end
end
