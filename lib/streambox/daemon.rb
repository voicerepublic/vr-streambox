require 'logger'
require 'json'
require 'ostruct'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "streambox/version"

# TODO introduce a proper state machine
module Streambox

  class Daemon

    #ENDPOINT = 'https://voicerepublic.com/api/devices'
    ENDPOINT = 'http://192.168.178.21:3000/api/devices'

    def initialize
      Thread.abort_on_exception = true
      @config = OpenStruct.new endpoint: ENDPOINT
      p @config
    end

    # TODO fallback to generated uuid
    def serial
      md = File.read('/proc/cpuinfo').match(/Serial\s*:\s*(.*)/)
      md.nil? ? serial_fallback : md[1]
    end

    def serial_fallback
      [%x[ whoami ].chomp, %x[ hostname ].chomp] * '@'
    end

    def subtype
      if File.exist?('/home/pi/subtype')
        File.read('/home/pi/subtype')
      else
        'dev'
      end
    end

    def payload
      { identifier: serial, type: 'box', subtype: subtype }
    end

    def apply_config(data)
      data.each do |key, value|
        puts "#{key}=#{value}"
        @config.send("#{key}=", value)
      end
    end

    def knock
      logger.info "Knocking..."
      response = faraday.get(@config.endpoint + '/' + serial)
      apply_config(JSON.parse(response.body))
    end

    def register
      logger.info "Registering..."
      response = faraday.post(@config.endpoint, payload)
      apply_config(JSON.parse(response.body))
      logger.info "Registration complete."
    end

    def report
      # TODO improve, add temperature
      %x[ uptime ]
    end

    def run
      knock
      register

      logger.info "Entering event machine loop..."
      EM.run {
        client = Faye::Client.new(@config.faye_url)
        ext = Faye::Authentication::ClientExtension.new(@config.faye_secret)
        client.add_extension(ext)

        client.subscribe(channel) { |message| process(message) }

        # reporter
        Thread.new do
          sleep @config.report_pause
          payload = report
          logger.debug "Reporting: #{payload}"
          publish event: 'report', report: payload
        end
      }
      logger.warn "Exiting."
    end

    def process(message)
      case message['event']
      # { event: 'start_streaming',
      #   icecast: { ... } }
      when 'start_streaming'
        icecast = OpenStruct.new(message['icecast'])
        logger.info "Streaming with #{icecast.inspect}"
        @streamer = Streamer.new(icecast)
        @streamer.start_streaming!
      # { event: 'stop_streaming' }
      when 'stop_streaming'
        logger.info "Stopped streaming."
        @streamer.stop_streaming!
      # { event: 'eval', eval: '41+1' }
      when 'eval'
        code = message['eval']
        logger.debug "Eval: #{code}"
        publish event: 'print', print: eval(code)
      when 'exit'
        logger.info "Exiting..."
        exit
      when 'shutdown'
        logger.info "Initiating shutdown..."
        %x[ sudo shutdown -h now ]
      else
        logger.warn "Unknown event: #{message.inspect}"
        publish event: 'unknown-event', message: message
      end
    end

    def channel
      "/proxy/#{@config.identifier}"
    end

    def publish(msg)
      client.publish('/proxies', msg.merge(identifier: @config.identifier))
    end

    def logger
      @logger ||= Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::DEBUG # TODO configure loglevel
        #logger.datetime_format = '%Y-%m-%d %H:%M:%S'
        #logger.formatter = proc do |severity, datetime, progname, msg|
        #  "#{datetime}: #{msg}\n"
        #end
      end
    end

    def faraday
      @faraday ||= Faraday.new(url: ENDPOINT) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end

  end
end
