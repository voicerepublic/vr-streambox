require 'logger'
require 'json'
require 'ostruct'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "streambox/version"
require "streambox/reporter"
require "streambox/streamer"

# TODO introduce a proper state machine
module Streambox

  class Daemon

    CLAIMS = [
      'A stream you stream alone is only a stream. A stream you stream together is reality. - John Lennon',
      "I stream. Sometimes I think that's the only right thing to do. - Haruki Murakami",
      'I stream my painting and I paint my stream. - Vincent van Gogh',
      "We are the music makers, and we are the streamers of streams. - Arthur O'Shaughnessy",
      'The future belongs to those who believe in the beauty of their streams. - Eleanor Roosevelt',
      'Hope is a waking stream. - Aristotle',
      'All that we see or seem is but a stream within a stream. - Edgar Allen Poe'
    ]

    ENDPOINT = 'https://voicerepublic.com/api/devices'

    attr_accessor :client

    def initialize
      Thread.abort_on_exception = true
      @config = OpenStruct.new endpoint: ENDPOINT, loglevel: Logger::INFO
      @reporter = Reporter.new
      banner
    end

    def identifier
      @reporter.serial
    end

    def payload
      {
        identifier: identifier,
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
      # TODO set system timezone and update clock
    end

    def knock
      logger.info "Knocking..."
      url = @config.endpoint + '/' + identifier
      logger.debug url
      response = faraday.get(url)
      apply_config(JSON.parse(response.body))
    end

    def register
      logger.info "Registering..."
      response = faraday.post(@config.endpoint, device: payload)
      if response.status != 200
        logger.warn "Registration failed."
        logger.warn response.body
        logger.warn "Exiting..."
        exit
      end
      apply_config(JSON.parse(response.body))
      logger.info "Registration complete."
    end

    def start_heartbeat
      logger.info "Start heartbeat..."
      Thread.new do
        loop do
          sleep @config.heartbeat_interval
          if client.nil?
            logger.warn "Skip heartbeat. Client not ready."
          else
            client.publish '/heartbeat', {
                             identifier: identifier,
                             interval: @config.heartbeat_interval
                           }
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
            logger.warn "Skip report. Client not ready."
          else
            client.publish '/report', {
                             identifier: identifier,
                             interval: @config.report_interval,
                             report: @reporter.report
                           }
          end
        end
      end
    end

    def run
      knock
      register
      start_heartbeat
      start_reporting

      logger.info "Entering event machine loop..."
      EM.run {
        logger.debug "Faye URL: #{@config.faye_url}"
        self.client = Faye::Client.new(@config.faye_url)
        logger.debug "Faye Secret: #{@config.faye_secret}"
        ext = Faye::Authentication::ClientExtension.new(@config.faye_secret)
        client.add_extension(ext)

        logger.debug "Subscribing to channel '#{channel}'..."
        client.subscribe(channel) { |message| dispatch(message) }

        publish event: 'print', print: 'Device ready.'
      }
      logger.warn "Exiting."
    end

    # TODO maybe rewrite handle_ methods to not use arguments
    def dispatch(message={})
      method = "handle_#{message['event']}"
      return send(method, message) if respond_to?(method)
      publish event: 'error', error: "Unknown message: #{message.inspect}"
    end

    # { event: 'start_streaming', icecast: { ... } }
    def handle_start_stream(message={})
      @streamer = Streamer.new(message['icecast'])
      @streamer.start!
      logger.info "Streaming with #{message.inspect}"
    end

    # { event: 'stop_streaming' }
    def handle_stop_stream(message={})
      @streamer.stop!
      logger.info "Stopped streaming."
    end

    # { event: 'eval', eval: '41+1' }
    def handle_eval(message={})
      code = message['eval']
      logger.debug "Eval: #{code}"
      output = eval(code)
    rescue => e
      output = 'Error: ' + e.message
    ensure
      publish event: 'print', print: output.inspect
    end

    # TODO exit, shutdown, and reboot should stop streaming first
    def handle_exit(message={})
      logger.info "Exiting..."
      exit
    end

    def handle_shutdown(message={})
      logger.info "Shutting down..."
      %x[ sudo shutdown -h now ]
    end

    def handle_reboot(message={})
      logger.info "Rebooting..."
      %x[ sudo reboot ]
    end

    def handle_print(message={})
      logger.debug "Print: #{message['print']}"
    end

    def handle_heartbeat(message={})
      # ignore
    end

    def handle_report(message={})
      logger.debug "Report: #{message.inspect}"
    end

    def handle_error(message={})
      logger.warn message.error
    end

    def handle_handshake(message={})
      publish event: 'print', print: 'Connection established.'
    end

    def channel
      "/device/#{identifier}"
    end

    def publish(msg={})
      client.publish(channel, msg)
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

    def banner
      system('figlet -t "%s"' % claim)
    end

    def claim
      CLAIMS[rand(CLAIMS.size)]
    end

  end
end
