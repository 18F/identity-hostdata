require 'rails'
require 'timecop'
require 'active_support/core_ext/time'
require 'login_gov/hostdata/railtie'

RSpec.describe LoginGov::Hostdata::Railtie do
  around do |ex|
    zone = Time.zone
    Time.zone = ActiveSupport::TimeZone['UTC']
    ex.run
    Time.zone = zone
  end

  describe 'config.lograge.custom_options' do
    subject(:config) { LoginGov::Hostdata::Railtie.config }

    let(:event) do
      ActiveSupport::Notifications::Event.new(
        'process_action.action_controller',
        start,
        finish,
        transaction_id,
        controller: 'Users::SessionsController',
        action: 'new',
        request: ActionDispatch::Request.new(headers),
        params: { foo: 'bar' },
        headers: headers,
        path: '/',
        response: instance_double(ActionDispatch::Response),
      )
    end

    let(:start) { Time.zone.now }
    let(:finish) { Time.zone.now }
    let(:transaction_id) { SecureRandom.uuid }
    let(:amzn_trace_id) { SecureRandom.hex }
    let(:headers) do
      {
        'X-Amzn-Trace-Id' => amzn_trace_id,
        'HTTP_HOST' => 'host.example.com',
        'HTTP_USER_AGENT' => 'Chrome 1234',
        'action_dispatch.remote_ip' => '1.2.3.4',
      }
    end
    let(:now) { Time.zone.now }

    it 'adds in timestamp, uuid, and pid, trace_id and omits extra noise' do
      payload = Timecop.freeze(now) do
        config.lograge.custom_options.call(event)
      end

      expect(payload).to_not include(:params, :headers, :request, :response)

      expect(payload).to match(
        uuid: /\A[0-9a-f-]+\Z/, # rough UUID regex
        pid: Process.pid,
        controller: 'Users::SessionsController',
        action: 'new',
        path: '/',
        timestamp: now.iso8601,
        host: 'host.example.com',
        user_agent: 'Chrome 1234',
        trace_id: amzn_trace_id,
        ip: '1.2.3.4',
      )
    end
  end
end
