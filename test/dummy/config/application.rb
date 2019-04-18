require 'rails'
# Pick the frameworks you want:
# require 'active_model/railtie'
# require 'active_job/railtie'
# require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
# require 'action_cable/engine'
# require 'sprockets/railtie'
require 'rails/test_unit/railtie'

module Dummy
  class Application < Rails::Application
    config.eager_load = false
    config.action_mailer.delivery_method = :test

    config.middleware.use ExceptionNotification::Rack,
                          email: {
                            email_prefix: '[Dummy ERROR] ',
                            sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
                            exception_recipients: %w[dummyexceptions@example.com],
                            email_headers: { 'X-Custom-Header' => 'foobar' },
                            sections: %w[new_section request session environment backtrace],
                            background_sections: %w[new_bkg_section backtrace data],
                            pre_callback: proc { |_opts, _notifier, _backtrace, _message, message_opts| message_opts[:pre_callback_called] = 1 },
                            post_callback: proc { |_opts, _notifier, _backtrace, _message, message_opts| message_opts[:post_callback_called] = 1 }
                          }
  end
end

Dummy::Application.initialize!
