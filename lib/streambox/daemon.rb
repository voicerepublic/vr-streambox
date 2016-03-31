require 'logger'
require 'json'
require 'ostruct'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "streambox/version"
require "streambox/reporter"

# TODO introduce a proper state machine
module Streambox

  class Daemon

    #ENDPOINT = 'https://voicerepublic.com/api/devices'
    ENDPOINT = 'http://192.168.178.21:3000/api/devices'
    #ENDPOINT = 'http://192.168.0.19:3000/api/devices'

    attr_accessor :client

    def initialize
      Thread.abort_on_exception = true
      @config = OpenStruct.new endpoint: ENDPOINT, loglevel: Logger::INFO
      @reporter = Reporter.new
    end

    def payload
      {
        identifier: @reporter.serial,
        type: 'Streambox',
        subtype: @reporter.subtype
      }
    end

    def apply_config(data)
      data.each do |key, value|
        logger.debug '-> %-20s %-20s' % [key, value]
        @config.send("#{key}=", value)
      end
      logger.level = @config.loglevel
    end

    def knock
      logger.info "Knocking..."
      response = faraday.get(@config.endpoint + '/' + @reporter.serial)
      apply_config(JSON.parse(response.body))
    end

    def register
      logger.info "Registering..."
      response = faraday.post(@config.endpoint, device: payload)
      apply_config(JSON.parse(response.body))
      logger.info "Registration complete."
    end

    def start_heartbeat
      logger.info "Start heartbeat..."
      Thread.new do
        loop do
          sleep @config.heartbeat_interval
          if client.nil?
            logger.debug "Skip heartbeat. Client not ready."
          else
            publish event: 'heartbeat'
          end
        end
      end
    end

    def start_reporting
      logger.info "Start reporting..."
      Thread.new do
        loop do
          sleep @config.report_interval
          if client.nil?
            logger.debug "Skip report. Client not ready."
          else
            payload = @reporter.report
            logger.debug "Report: #{payload.inspect}"
            publish event: 'report', report: payload
          end
        end
      end
    end

    def run
      knock
      register
      start_reporting

      logger.info "Entering event machine loop..."
      EM.run {
        logger.debug "Faye URL: #{@config.faye_url}"
        self.client = Faye::Client.new(@config.faye_url)
        logger.debug "Faye Secret: #{@config.faye_secret}"
        ext = Faye::Authentication::ClientExtension.new(@config.faye_secret)
        client.add_extension(ext)

        logger.debug "Subscribing #{channel}..."
        client.subscribe(channel) { |message| process(message) }

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
      "/device/#{@reporter.serial}"
    end

    def publish(msg={})
      client.publish('/proxies', msg.merge(identifier: @reporter.serial))
    end

    def logger
      @logger ||= Logger.new(STDOUT).tap do |logger|
        logger.level = @config.loglevel
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity[0]} #{datetime.strftime('%H:%M:%S')} #{msg}\n"
        end
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
