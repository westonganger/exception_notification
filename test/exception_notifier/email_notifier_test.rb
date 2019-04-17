require 'test_helper'
require 'action_mailer'

class EmailNotifierTest < ActiveSupport::TestCase
  setup do
    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')

    @exception = ZeroDivisionError.new('divided by 0')
    @exception.set_backtrace(['test/exception_notifier/email_notifier_test.rb:20'])

    @email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      email_headers: { 'X-Custom-Header' => 'foobar' },
      sections: %w[new_section request session environment backtrace],
      background_sections: %w[new_bkg_section backtrace data],
      pre_callback: proc { |_opts, _notifier, _backtrace, _message, message_opts| message_opts[:pre_callback_called] = 1 },
      post_callback: proc { |_opts, _notifier, _backtrace, _message, message_opts| message_opts[:post_callback_called] = 1 }
    )

    @mail = @email_notifier.call(
      @exception,
      data: { job: 'DivideWorkerJob', payload: '1/0', message: 'My Custom Message' }
    )
  end

  test 'should call pre/post_callback if specified' do
    assert_equal @email_notifier.options[:pre_callback_called], 1
    assert_equal @email_notifier.options[:post_callback_called], 1
  end

  test 'sends mail with correct content' do
    assert_equal %("Dummy Notifier" <dummynotifier@example.com>), @mail[:from].value
    assert_equal %w[dummyexceptions@example.com], @mail.to
    assert_equal '[Dummy ERROR]  (ZeroDivisionError) "divided by 0"', @mail.subject
    assert_equal 'foobar', @mail['X-Custom-Header'].value
    assert_equal 'text/plain; charset=UTF-8', @mail.content_type
    assert_equal [], @mail.attachments

    body = <<-BODY.strip_heredoc
      A ZeroDivisionError occurred in background at Sat, 20 Apr 2013 20:58:55 UTC +00:00 :

        divided by 0
        test/exception_notifier/email_notifier_test.rb:20

      -------------------------------
      New bkg section:
      -------------------------------

        * New background section for testing

      -------------------------------
      Backtrace:
      -------------------------------

        test/exception_notifier/email_notifier_test.rb:20

      -------------------------------
      Data:
      -------------------------------

        * data: {:job=>"DivideWorkerJob", :payload=>"1/0", :message=>"My Custom Message"}


    BODY

    assert_equal body, @mail.decode_body
  end

  test 'should have default sections overridden' do
    %w[new_section request session environment backtrace].each do |section|
      assert_includes @email_notifier.sections, section
    end
  end

  test 'should have default background sections' do
    %w[new_bkg_section backtrace data].each do |section|
      assert_includes @email_notifier.background_sections, section
    end
  end

  test 'should have mailer_parent by default' do
    assert_equal @email_notifier.mailer_parent, 'ActionMailer::Base'
  end

  test 'should have template_path by default' do
    assert_equal @email_notifier.template_path, 'exception_notifier'
  end

  test 'should normalize multiple digits into one N' do
    assert_equal 'N foo N bar N baz N',
                 ExceptionNotifier::EmailNotifier.normalize_digits('1 foo 12 bar 123 baz 1234')
  end

  test "mail should prefix exception class with 'an' instead of 'a' when it starts with a vowel" do
    begin
      raise ArgumentError
    rescue StandardError => e
      @vowel_exception = e
      @vowel_mail = @email_notifier.create_email(@vowel_exception)
    end

    assert_includes @vowel_mail.encoded, "An ArgumentError occurred in background at #{Time.current}"
  end

  test 'should not send notification if one of ignored exceptions' do
    begin
      raise AbstractController::ActionNotFound
    rescue StandardError => e
      @ignored_exception = e
      unless ExceptionNotifier.ignored_exceptions.include?(@ignored_exception.class.name)
        ignored_mail = @email_notifier.create_email(@ignored_exception)
      end
    end

    assert_equal @ignored_exception.class.inspect, 'AbstractController::ActionNotFound'
    assert_nil ignored_mail
  end

  test 'should encode environment strings' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      sender_address: '<dummynotifier@example.com>',
      exception_recipients: %w[dummyexceptions@example.com],
      deliver_with: :deliver_now
    )

    mail = email_notifier.create_email(
      @exception,
      env: {
        'REQUEST_METHOD' => 'GET',
        'rack.input' => '',
        'invalid_encoding' => "R\xC3\xA9sum\xC3\xA9".force_encoding(Encoding::ASCII)
      }
    )

    assert_match(/invalid_encoding\s+: R__sum__/, mail.encoded)
  end

  test 'should send email using ActionMailer' do
    ActionMailer::Base.deliveries.clear
    @email_notifier.call(@exception)
    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test 'should be able to specify ActionMailer::MessageDelivery method' do
    ActionMailer::Base.deliveries.clear

    deliver_with = if ActionMailer.version < Gem::Version.new('4.2')
                     :deliver
                   else
                     :deliver_now
                   end

    email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      deliver_with: deliver_with
    )

    email_notifier.call(@exception)

    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test 'should lazily evaluate exception_recipients' do
    exception_recipients = %w[first@example.com second@example.com]
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: -> { [exception_recipients.shift] },
      delivery_method: :test
    )

    mail = email_notifier.call(@exception)
    assert_equal %w[first@example.com], mail.to
    mail = email_notifier.call(@exception)
    assert_equal %w[second@example.com], mail.to
  end

  test 'should prepend accumulated_errors_count in email subject if accumulated_errors_count larger than 1' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      delivery_method: :test
    )

    mail = email_notifier.call(@exception, accumulated_errors_count: 3)
    assert mail.subject.start_with?('[Dummy ERROR] (3 times) (ZeroDivisionError)')
  end
end
