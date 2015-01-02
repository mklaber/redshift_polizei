require 'rake'
require 'daemons'

#
# script to run the Que workers in background processes
# easily manageable using startstop/restart commands
#

current_dir = Dir.pwd
Daemons.run_proc(__FILE__) do
  Dir.chdir(current_dir)
  Rake.application.init
  Rake.application.load_rakefile
  Rake::Task['que:work'].invoke
end
