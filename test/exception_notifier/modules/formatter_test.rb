require 'test_helper'
require 'timecop'

class FormatterTest < ActiveSupport::TestCase
  class HomeController < ActionController::Metal
    def index; end
  end

  setup do
    @exception = RuntimeError.new('test')
    Timecop.freeze('2018-12-09 12:07:16 UTC')
  end

  teardown do
    Timecop.return
  end

  #
  # #title
  #
  test 'title returns correct content' do
    formatter = ExceptionNotifier::Formatter.new(@exception)
    assert_equal '⚠️ Error occurred in test ⚠️', formatter.title
  end

  #
  # #subtitle
  #
  test 'subtitle without accumulated error' do
    formatter = ExceptionNotifier::Formatter.new(@exception)
    assert_equal 'A *RuntimeError* occurred.', formatter.subtitle
  end

  test 'subtitle with accumulated error' do
    formatter = ExceptionNotifier::Formatter.new(@exception, accumulated_errors_count: 3)
    assert_equal '3 *RuntimeError* occurred.', formatter.subtitle
  end

  test 'subtitle with controller' do
    controller = HomeController.new
    controller.process(:index)

    env = Rack::MockRequest.env_for(
      '/', 'action_controller.instance' => controller
    )

    formatter = ExceptionNotifier::Formatter.new(@exception, env: env)
    assert_equal 'A *RuntimeError* occurred in *home#index*.', formatter.subtitle
  end

  #
  # #app_name
  #
  test 'app_name defaults to Rails app name' do
    formatter = ExceptionNotifier::Formatter.new(@exception)
    assert_equal 'dummy', formatter.app_name
  end

  test 'app_name can be overwritten using options' do
    formatter = ExceptionNotifier::Formatter.new(@exception, app_name: 'test')
    assert_equal 'test', formatter.app_name
  end

  #
  # #request_message
  #
  test 'request_message when env set' do
    text = [
      '',
      '*Request:*',
      '```',
      '* url : http://test.address/?id=foo',
      '* http_method : GET',
      '* ip_address : 127.0.0.1',
      '* parameters : {"id"=>"foo"}',
      '* timestamp : 2018-12-09 12:07:16 UTC',
      '```'
    ].join("\n")

    env = Rack::MockRequest.env_for(
      '/',
      'HTTP_HOST' => 'test.address',
      'REMOTE_ADDR' => '127.0.0.1',
      params: { id: 'foo' }
    )

    formatter = ExceptionNotifier::Formatter.new(@exception, env: env)
    assert_equal text, formatter.request_message
  end

  test 'request_message when env not set' do
    formatter = ExceptionNotifier::Formatter.new(@exception)
    assert_nil formatter.request_message
  end

  #
  # #backtrace_message
  #
  test 'backtrace_message when backtrace set' do
    text = [
      '',
      '*Backtrace:*',
      '```',
      "* app/controllers/my_controller.rb:53:in `my_controller_params'",
      "* app/controllers/my_controller.rb:34:in `update'",
      '```'
    ].join("\n")

    @exception.set_backtrace([
                               "app/controllers/my_controller.rb:53:in `my_controller_params'",
                               "app/controllers/my_controller.rb:34:in `update'"
                             ])

    formatter = ExceptionNotifier::Formatter.new(@exception)
    assert_equal text, formatter.backtrace_message
  end

  test 'backtrace_message when no backtrace' do
    formatter = ExceptionNotifier::Formatter.new(@exception)
    assert_nil formatter.backtrace_message
  end
end
