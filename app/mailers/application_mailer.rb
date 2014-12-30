ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.view_paths = File.expand_path(File.dirname(__FILE__) + '/../views/')
MAIL_CONFIG = YAML::load_file(File.expand_path(File.dirname(__FILE__) + '/../../' + File.join('config', 'mail.yml')))
ActionMailer::Base.smtp_settings = MAIL_CONFIG.symbolize_keys

module Mailers
  class ApplicationMailer < ActionMailer::Base
    default from: ActionMailer::Base.smtp_settings[:user_name]
  end
end
