# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

begin
  require 'coveralls'
  Coveralls.wear!
rescue LoadError
  warn 'warning: coveralls gem not found; skipping Coveralls'
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'exception_notification'

require 'dummy/config/application.rb'
require 'rails/test_help'

require 'mocha/setup'

Rails.backtrace_cleaner.remove_silencers!
ExceptionNotifier.testing_mode!
