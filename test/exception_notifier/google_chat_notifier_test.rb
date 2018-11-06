require 'test_helper'
require 'httparty'

class GoogleChatNotifierTest < ActiveSupport::TestCase

  test "should send notification if properly configured" do
    options = {
      :webhook_url => 'http://localhost:8000'
    }
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new
    google_chat_notifier.httparty = FakeHTTParty.new

    options = google_chat_notifier.call ArgumentError.new("foo"), options

    body = ActiveSupport::JSON.decode options[:body]
    assert body.has_key? 'text'

    text = body['text'].split("\n")
    assert_equal 6, text.size
    assert_equal 'Application: *dummy*', text[1]
    assert_equal 'An *ArgumentError* occured.', text[2]
    assert_equal '*foo*', text[5]
  end

  test "should use 'An' for exceptions count if :accumulated_errors_count option is nil" do
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new
    exception = ArgumentError.new("foo")
    google_chat_notifier.instance_variable_set(:@exception, exception)
    google_chat_notifier.instance_variable_set(:@options, {})

    assert_includes google_chat_notifier.send(:header), "An *ArgumentError* occured."
  end

  test "shoud use direct errors count if :accumulated_errors_count option is 5" do
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new
    exception = ArgumentError.new("foo")
    google_chat_notifier.instance_variable_set(:@exception, exception)
    google_chat_notifier.instance_variable_set(:@options, { accumulated_errors_count: 5 })

    assert_includes google_chat_notifier.send(:header), "5 *ArgumentError* occured."
  end

  test "Message request should be formatted as hash" do
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new
    request_items = { url: 'http://test.address',
                      http_method: :get,
                      ip_address: '127.0.0.1',
                      parameters: '{"id"=>"foo"}',
                      timestamp: Time.parse('2018-08-13 12:13:24 UTC') }
    google_chat_notifier.instance_variable_set(:@request_items, request_items)

    message_request =  google_chat_notifier.send(:message_request).join("\n")
    assert_includes message_request, '* url : http://test.address'
    assert_includes message_request, '* http_method : get'
    assert_includes message_request, '* ip_address : 127.0.0.1'
    assert_includes message_request, '* parameters : {"id"=>"foo"}'
    assert_includes message_request, '* timestamp : 2018-08-13 12:13:24 UTC'
  end

  test 'backtrace with less than 3 lines should be displayed fully' do
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new

    backtrace = ["app/controllers/my_controller.rb:53:in `my_controller_params'", "app/controllers/my_controller.rb:34:in `update'"]
    google_chat_notifier.instance_variable_set(:@backtrace, backtrace)

    message_backtrace =  google_chat_notifier.send(:message_backtrace).join("\n")
    assert_includes message_backtrace, "* app/controllers/my_controller.rb:53:in `my_controller_params'"
    assert_includes message_backtrace, "* app/controllers/my_controller.rb:34:in `update'"
  end

  test 'backtrace with more than 3 lines should display only top 3 lines' do
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new

    backtrace = ["app/controllers/my_controller.rb:99:in `specific_function'", "app/controllers/my_controller.rb:70:in `specific_param'", "app/controllers/my_controller.rb:53:in `my_controller_params'", "app/controllers/my_controller.rb:34:in `update'"]
    google_chat_notifier.instance_variable_set(:@backtrace, backtrace)

    message_backtrace =  google_chat_notifier.send(:message_backtrace).join("\n")
    assert_includes message_backtrace, "* app/controllers/my_controller.rb:99:in `specific_function'"
    assert_includes message_backtrace, "* app/controllers/my_controller.rb:70:in `specific_param'"
    assert_includes message_backtrace, "* app/controllers/my_controller.rb:53:in `my_controller_params'"
    assert_not_includes message_backtrace, "* app/controllers/my_controller.rb:34:in `update'"
  end

  test 'Get text with backtrace and request info' do
    google_chat_notifier = ExceptionNotifier::GoogleChatNotifier.new

    backtrace = ["app/controllers/my_controller.rb:53:in `my_controller_params'", "app/controllers/my_controller.rb:34:in `update'"]
    google_chat_notifier.instance_variable_set(:@backtrace, backtrace)

    request_items = { url: 'http://test.address',
                      http_method: :get,
                      ip_address: '127.0.0.1',
                      parameters: '{"id"=>"foo"}',
                      timestamp: Time.parse('2018-08-13 12:13:24 UTC') }
    google_chat_notifier.instance_variable_set(:@request_items, request_items)

    google_chat_notifier.instance_variable_set(:@options, {accumulated_errors_count: 0})

    google_chat_notifier.instance_variable_set(:@application_name, 'dummy')

    exception = ArgumentError.new("foo")
    google_chat_notifier.instance_variable_set(:@exception, exception)

    text = google_chat_notifier.send(:exception_text)
    expected_text = %q(
Application: *dummy*
An *ArgumentError* occured.

⚠️ Error 500 in test ⚠️
*foo*

*Request:*
```
* url : http://test.address
* http_method : get
* ip_address : 127.0.0.1
* parameters : {"id"=>"foo"}
* timestamp : 2018-08-13 12:13:24 UTC
```

*Backtrace:*
```
* app/controllers/my_controller.rb:53:in `my_controller_params'
* app/controllers/my_controller.rb:34:in `update'
```)
    assert_equal text, expected_text
  end
end
