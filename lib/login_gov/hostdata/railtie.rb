begin
  require 'lograge'
rescue LoadError => e
  STDERR.puts 'lograge is required by the LoginGov::Hostdata::Railtie, please add it to the Gemfile'
  raise e
end

if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new('6.1')
  raise 'LoginGov::Hostdata::Railtie needs rails >= 6.1 to log request info, please upgrade'
end

require 'login_gov/hostdata/log_formatter'
require 'securerandom'

module LoginGov
  module Hostdata
    class Railtie < Rails::Railtie
      config.lograge.enabled = true

      config.log_formatter = if Rails.env.development?
        LoginGov::Hostdata::DevelopmentLogFormatter
      else
        LoginGov::Hostdata::LogFormatter
      end

      if Rails.env.development? || Rails.env.production?
        config.lograge.formatter = Lograge::Formatters::Json.new
      end

      config.lograge.custom_options = lambda do |event|
        event.payload[:timestamp] = Time.zone.now.iso8601
        event.payload[:uuid] = SecureRandom.uuid
        event.payload[:pid] = Process.pid
        event.payload[:user_agent] = event.payload[:request].user_agent
        event.payload[:ip] = event.payload[:request].remote_ip
        event.payload[:host] = event.payload[:request].host
        event.payload[:trace_id] = event.payload[:headers]['X-Amzn-Trace-Id']
        event.payload.except(:params, :headers, :request, :response)
      end
    end
  end
end
