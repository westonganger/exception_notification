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

  test 'should send html email when selected html format' do
    begin
      post :create, method: :post
    rescue StandardError => e
      @exception = e
      custom_env = request.env
      custom_env['exception_notifier.options'] ||= {}
      custom_env['exception_notifier.options'][:email_format] = :html
      @mail = @email_notifier.create_email(@exception, env: custom_env)
    end

    assert_includes @mail.content_type, 'multipart/alternative'
  end
end

class PostsControllerTestWithoutVerboseSubject < ActionController::TestCase
  tests PostsController
  setup do
    @email_notifier = ExceptionNotifier::EmailNotifier.new(verbose_subject: false)
    begin
      post :create, method: :post
    rescue StandardError => e
      @exception = e
      @mail = @email_notifier.create_email(@exception, env: request.env)
    end
  end

  test 'should not include exception message in subject' do
    assert_includes @mail.subject, '[ERROR]'
    assert_includes @mail.subject, '(NoMethodError)'
    refute_includes @mail.subject, 'undefined method'
  end
end

class PostsControllerTestWithoutControllerAndActionNames < ActionController::TestCase
  tests PostsController
  setup do
    @email_notifier = ExceptionNotifier::EmailNotifier.new(include_controller_and_action_names_in_subject: false)
    begin
      post :create, method: :post
    rescue StandardError => e
      @exception = e
      @mail = @email_notifier.create_email(@exception, env: request.env)
    end
  end

  test 'should include controller and action names in subject' do
    assert_includes @mail.subject, '[ERROR]'
    assert_includes @mail.subject, '(NoMethodError)'
    refute_includes @mail.subject, 'posts#create'
  end
end
