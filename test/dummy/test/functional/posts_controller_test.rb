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
end
