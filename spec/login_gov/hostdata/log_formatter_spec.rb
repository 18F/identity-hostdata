require 'spec_helper'
require 'login_gov/hostdata/log_formatter'

RSpec.describe LoginGov::Hostdata::LogFormatter do
  subject(:log_formatter) { described_class.new }

  describe '#call' do
    it 'prints expected standard messages' do
      now = Time.utc(2019, 1, 2, 3, 4, 5)
      expect(log_formatter.call('INFO', now, 'progname', 'hello')).
        to eq("I, [2019-01-02T03:04:05.000000 ##{Process.pid}]  INFO -- progname: hello\n")
    end

    it 'prints JSON-like messages as-is' do
      expect(log_formatter.call('INFO', Time.now, 'progname', '{"hello"}')).
        to eq('{"hello"}' + "\n")
    end
  end
end

RSpec.describe LoginGov::Hostdata::DevelopmentLogFormatter do
  subject(:log_formatter) { described_class.new }

  describe '#call' do
    it 'prints ANSI escaped messages as-is' do
      now = Time.utc(2019, 1, 2, 3, 4, 5)
      msg = "\e[1;31mhello\e[m"
      expect(log_formatter.call('INFO', now, 'progname', msg)).
        to eq(msg + "\n")
    end

    it 'prints expected messages otherwise' do
      now = Time.utc(2019, 1, 2, 3, 4, 5)
      expect(log_formatter.call('INFO', now, 'progname', 'hello')).
        to eq("I, [2019-01-02T03:04:05.000000 ##{Process.pid}]  INFO -- progname: hello\n")
    end
  end
end
