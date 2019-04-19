begin
  require 'coveralls'
  Coveralls.wear!
rescue LoadError
  warn 'warning: coveralls gem not found; skipping Coveralls'
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'exception_notification'

require 'minitest/autorun'
require 'mocha/minitest'
require 'active_support/test_case'
require 'action_mailer'

ExceptionNotifier.testing_mode!
Time.zone = 'UTC'
ActionMailer::Base.delivery_method = :test
