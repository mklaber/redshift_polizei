require './lib/global_config'
GlobalConfig.load_config_file('deploy', 'config/polizei.yml')
SERVER_URL  = GlobalConfig.deploy('deploy_server_url')

server SERVER_URL, :roles => %w{app web db cron}
set :rack_env, 'production'
