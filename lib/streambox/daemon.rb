require 'eventmachine'
require 'trickery/configurability'
require 'faye'
require 'faye-authentication'

require "streambox/version"
require "streambox/serial"

module Streambox

  class Daemon

    CONFIGFILE = File.expand_path('streambox.yml', Dir.pwd)

    CONFIG = [
      %w( -c --config      config ) << CONFIGFILE,
      %w( -f --faye-url    faye.url    http://voicerepublic.com:9292/faye ),
      %w( -t --faye-secret faye.secret there-is-no-default-secret ),
      %w( -i --identifier  identifier  there-is-no-default-identifier),
      %w( -n --name        name        there-is-no-default-name),
      %w( -r --report      report      30 )
    ]

    def new
      Thread.abort_on_exception = true
      @config = Trickery::Configurability.new('streambox', CONFIG)
    end

    def run
      EM.run {
        client = Faye::Client.new(@config.faye.url)
        ext = Faye::Authentication::ClientExtension.new(@config.faye.secret)
        client.add_extension(ext)

        client.subscribe(channel) do |message|
          case message['event']
          # { event: 'start_streaming',
          #   icecast: { ... } }
          when 'start_streaming'
            icecast = OpenStruct.new(message['icecast'])
            @streamer = Streamer.new(icecast)
            @streamer.start_streaming!
          # { event: 'stop_streaming' }
          when 'stop_streaming'
            @streamer.stop_streaming!
          # { event: 'eval', eval: '41+1' }
          when 'eval'
            publish event: 'print', print: eval(message['exec'])
          else
            publish event: 'unknown-event', message: message
          end
        end

        publish event: 'register'

        # reporter
        Thread.new do
          sleep @config.report
          # TODO improve
          publish event: 'report', report: %x[ uptime ]
        end
      }
    end

    private

    def channel
      "/proxy/#{@config.identifier}"
    end

    def publish(msg)
      client.publish('/proxies', msg.merge(identifier: @config.identifier))
    end

  end
end
