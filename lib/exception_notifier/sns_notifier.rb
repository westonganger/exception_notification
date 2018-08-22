module ExceptionNotifier
  class SnsNotifier < BaseNotifier
    def initialize(options)
      super

      raise ArgumentError.new "You must provide 'region' option" unless options[:region]
      raise ArgumentError.new "You must provide 'access_key_id' option" unless options[:access_key_id]
      raise ArgumentError.new "You must provide 'secret_access_key' option" unless options[:secret_access_key]

      @notifier = Aws::SNS::Client.new(
        region: options[:region],
        access_key_id: options[:access_key_id],
        secret_access_key: options[:secret_access_key]
      )
      @options = default_options.merge(options)
    end

    def call(exception, custom_opts = {})
      custom_options = options.merge(custom_opts)

      subject = build_subject(exception, custom_options)
      message = build_message(exception, custom_options)

      notifier.publish(
        topic_arn: custom_options[:topic_arn],
        message: message,
        subject: subject
      )
    end

    private

    attr_reader :notifier, :options

    def build_subject(exception, options)
      subject = "#{options[:sns_prefix]} - "
      subject << accumulated_exceptions_text(exception, options)
      subject << " occurred"
      subject.length > 120 ? subject[0...120] + "..." : subject
    end

    def build_message(exception, options)
      exception.class
    end

    def accumulated_exceptions_text(exception, options)
      errors_count = options[:accumulated_errors_count].to_i
      measure_word = errors_count > 1 ? errors_count : (exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A')
      "#{measure_word} #{exception.class.to_s}"
    end

    def default_options
      {
        sns_prefix: '[ERROR]',
      }
    end
  end
end
