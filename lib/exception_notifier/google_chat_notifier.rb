require 'action_dispatch'
require 'active_support/core_ext/time'

module ExceptionNotifier
  class GoogleChatNotifier
    include ExceptionNotifier::BacktraceCleaner

    class MissingController
      def method_missing(*args, &block)
      end
    end

    attr_accessor :httparty

    def initialize(options = {})
      super()
      @default_options = options
      @httparty = HTTParty
    end

    def call(exception, options = {})
      @options = options.merge(@default_options)
      @exception = exception
      @backtrace = exception.backtrace ? clean_backtrace(exception) : nil

      @env = @options.delete(:env)

      @application_name = @options.delete(:app_name) || Rails.application.class.parent_name.underscore

      @webhook_url = @options.delete(:webhook_url)
      raise ArgumentError.new "You must provide 'webhook_url' parameter." unless @webhook_url

      unless @env.nil?
        @controller = @env['action_controller.instance'] || MissingController.new

        request = ActionDispatch::Request.new(@env)

        @request_items = { url: request.original_url,
                           http_method: request.method,
                           ip_address: request.remote_ip,
                           parameters: request.filtered_parameters,
                           timestamp: Time.current }
      else
        @controller = @request_items = nil
      end


      @options[:body] = payload.to_json
      @options[:headers] ||= {}
      @options[:headers].merge!({ 'Content-Type' => 'application/json' })

      @httparty.post(@webhook_url, @options)
    end

    private

    def payload
      {
        text: exception_text
      }
    end

    def header
      errors_count = @options[:accumulated_errors_count].to_i
      text = ['']

      text << "Application: *#{@application_name}*"
      text << "#{errors_count > 1 ? errors_count : 'An'} *#{@exception.class}* occured" + if @controller then " in *#{controller_and_method}*." else "." end

      text
    end

    def exception_text
      text = []

      text << header
      text << ''

      text << "⚠️ Error 500 in #{Rails.env} ⚠️"
      text << "*#{@exception.message.gsub('`', %q('))}*"

      if @request_items
        text << ''
        text += message_request
      end

      if @backtrace
        text << ''
        text += message_backtrace
      end

      text.join("\n")
    end

    def message_request
      text = []

      text << "*Request:*"
      text << "```"
      text << hash_presentation(@request_items)
      text << "```"

      text
    end

    def hash_presentation(hash)
      text = []

      hash.each do |key, value|
        text << "* #{key} : #{value}"
      end

      text.join("\n")
    end

    def message_backtrace(size = 3)
      text = []

      size = @backtrace.size < size ? @backtrace.size : size
      text << "*Backtrace:*"
      text << "```"
      size.times { |i| text << "* " + @backtrace[i] }
      text << "```"

      text
    end

    def controller_and_method
      if @controller
        "#{@controller.controller_name}##{@controller.action_name}"
      else
        ""
      end
    end
  end
end
