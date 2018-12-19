# To run the application: ruby sample_app.rb
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'rails', '5.0.0'
  gem 'exception_notification', '4.3.0'
  gem 'httparty', '0.15.7'
end

class SampleApp < Rails::Application
  config.middleware.use ExceptionNotification::Rack,
  # -----------------------------------
  # Change this with the notifier you want to test
  # https://github.com/smartinez87/exception_notification#notifiers
                        webhook: {
                          url: 'http://domain.com:5555/hubot/path'
                        }
  # -----------------------------------

  config.secret_key_base = 'my secret key base'
  config.logger = Logger.new($stdout)
  Rails.logger = config.logger

  routes.draw do
    get 'raise_exception', to: 'exceptions#sample'
  end
end

require 'action_controller/railtie'
require 'active_support'

class ExceptionsController < ActionController::Base
  include Rails.application.routes.url_helpers

  def sample
    raise 'Sample exception raised, you should receive a notification!'
  end
end

require 'minitest/autorun'

class Test < Minitest::Test
  include Rack::Test::Methods

  def test_raise_exception
    get '/raise_exception'
  end

  private

  def app
    Rails.application
  end
end
