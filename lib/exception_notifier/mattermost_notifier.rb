require 'httparty'

module ExceptionNotifier
  class MattermostNotifier < BaseNotifier
    def call(exception, options = {})
      @options = options.merge(base_options)
      @exception = exception

      @formatter = Formatter.new(
        exception,
        env: @options.delete(:env),
        app_name: @options.delete(:app_name),
        accumulated_errors_count: @options[:accumulated_errors_count]
      )

      avatar = @options.delete(:avatar)
      channel = @options.delete(:channel)
      @gitlab_url = @options.delete(:git_url)
      @webhook_url = @options.delete(:webhook_url)
      raise ArgumentError, "You must provide 'webhook_url' parameter." unless @webhook_url

      payload = {
        text: message_text.compact.join("\n")
      }
      payload[:username] = @options.delete(:username) || 'Exception Notifier'
      payload[:icon_url] = avatar if avatar
      payload[:channel] = channel if channel

      @options[:body] = payload.to_json
      @options[:headers] ||= {}
      @options[:headers]['Content-Type'] = 'application/json'

      HTTParty.post(@webhook_url, @options)
    end

    private

    attr_reader :formatter

    def message_text
      text = [
        '@channel',
        "### #{formatter.title}",
        formatter.subtitle,
        "*#{@exception.message}*"
      ]

      if (request = formatter.request_message.presence)
        text << '### Request'
        text << request
      end

      if (backtrace = formatter.backtrace_message.presence)
        text << '### Backtrace'
        text << backtrace
      end

      text << message_issue_link if @gitlab_url

      text
    end

    def message_issue_link
      link = [@gitlab_url, formatter.app_name, 'issues', 'new'].join('/')
      params = {
        'issue[title]' => ['[BUG] Error 500 :',
                           formatter.controller_and_action || '',
                           "(#{@exception.class})",
                           @exception.message].compact.join(' ')
      }.to_query

      "[Create an issue](#{link}/?#{params})"
    end
  end
end
