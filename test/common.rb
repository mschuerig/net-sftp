require 'test/unit'
require 'mocha'

begin
  gem 'net-ssh', ">= 2.0.0"
  require 'net/ssh'
rescue LoadError
  $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../net-ssh/lib"
  $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../net-ssh.v2/lib"

  begin
    require 'net/ssh'
    require 'net/ssh/version'
    raise LoadError, "wrong version" unless Net::SSH::Version::STRING >= '1.99.0'
  rescue LoadError => e
    abort "could not load net/ssh v2 (#{e.inspect})"
  end
end

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'net/sftp'
require 'net/sftp/constants'
require 'net/ssh/test'

class Net::SFTP::TestCase < Test::Unit::TestCase
  include Net::SFTP::Constants
  include Net::SSH::Test

  def default_test
    # do nothing, this is just hacky-hack to work around Test::Unit's
    # insistence that all TestCase subclasses have at least one test
    # method defined.
  end

  protected

    def sftp(options={})
      @sftp ||= Net::SFTP::Session.new(connection(options))
    end

    def expect_sftp_session(opts={})
      story do |session|
        channel = session.opens_channel
        channel.sends_subsystem("sftp")
        channel.sends_packet(FXP_INIT, :long, opts[:client_version] || Net::SFTP::Session::HIGHEST_PROTOCOL_VERSION_SUPPORTED)
        channel.gets_packet(FXP_VERSION, :long, opts[:server_version] || Net::SFTP::Session::HIGHEST_PROTOCOL_VERSION_SUPPORTED)
        yield channel if block_given?
      end
    end

    def assert_scripted_command
      assert_scripted do
        sftp.connect!
        yield
        sftp.loop
      end
    end
end

class Net::SSH::Test::Channel
  def gets_packet(type, *args)
    gets_data(sftp_packet(type, *args))
  end

  def sends_packet(type, *args)
    sends_data(sftp_packet(type, *args))
  end

  private

    def sftp_packet(type, *args)
      data = Net::SSH::Buffer.from(*args)
      Net::SSH::Buffer.from(:long, data.length+1, :byte, type, :raw, data).to_s
    end
end

class ProgressHandler
  def initialize(progress_ref)
    @progress = progress_ref
  end

  def on_open(*args)
    @progress << [:open, *args]
  end

  def on_put(*args)
    @progress << [:put, *args]
  end

  def on_close(*args)
    @progress << [:close, *args]
  end

  def on_finish(*args)
    @progress << [:finish, @args]
  end
end