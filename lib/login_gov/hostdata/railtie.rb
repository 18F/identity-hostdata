begin
  require 'lograge'
rescue LoadError => e
  STDERR.puts 'lograge is required by the LoginGov::Hostdata::Railtie, please add it to the Gemfile'
  raise e
end

require 'login_gov/hostdata/log_formatter'
require 'securerandom'

module LoginGov
  module Hostdata
    class Railtie < Rails::Railtie
      config.log_formatter = if Rails.env.development?
        LoginGov::Hostdata::DevelopmentLogFormatter
      else
        LoginGov::Hostdata::LogFormatter
      end

      if Rails.env.development? || Rails.env.production?
        config.lograge.enabled = true
        config.lograge.formatter = Lograge::Formatters::Json.new
      end

      config.lograge.custom_options = lambda do |event|
        event.payload[:timestamp] = Time.zone.now.iso8601
        event.payload[:uuid] = SecureRandom.uuid
        event.payload[:pid] = Process.pid
        event.payload.except(:params, :headers, :request, :response)
      end
    end
  end
end
