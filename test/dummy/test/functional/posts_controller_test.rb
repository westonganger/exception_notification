require 'test_helper'

class PostsControllerTest < ActionController::TestCase
  setup do
    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')
    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    begin
      post :create, method: :post, params: { secret: 'secret' }
    rescue StandardError => e
      @exception = e
      @mail = @email_notifier.create_email(@exception, env: request.env, data: { message: 'My Custom Message' })
    end
  end

  test 'should ignore exception if from unwanted crawler' do
    request.env['HTTP_USER_AGENT'] = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
    begin
      post :create, method: :post
    rescue StandardError => e
      @exception = e
      custom_env = request.env
      custom_env['exception_notifier.options'] ||= {}
      custom_env['exception_notifier.options'][:ignore_crawlers] = %w[Googlebot]
      ignore_array = custom_env['exception_notifier.options'][:ignore_crawlers]
      unless ExceptionNotification::Rack.new(Dummy::Application, custom_env['exception_notifier.options']).send(:from_crawler, custom_env, ignore_array)
        ignored_mail = @email_notifier.create_email(@exception, env: custom_env)
      end
    end

    assert_nil ignored_mail
  end
end
