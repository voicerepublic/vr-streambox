require 'logger'
require 'json'
require 'ostruct'
require 'uri'
require 'fileutils'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "streambox/version"
require "streambox/reporter"
require "streambox/streamer"
require "streambox/resilient_process"
require "streambox/banner"

# TODO introduce a proper state machine
module Streambox

  class Daemon

    ENDPOINT = 'https://voicerepublic.com/api/devices'

    attr_accessor :client

    def initialize
      Thread.abort_on_exception = true
      @config = OpenStruct.new endpoint: ENDPOINT,
                               loglevel: Logger::INFO,
                               device: 'dsnooped',
                               sync_interval: 60 * 10, # 10 minutes
                               check_record_interval: 1,
                               check_stream_interval: 1
      @reporter = Reporter.new
      Banner.new
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
        @config.send("#{key}=", value)
      end
      logger.level = @config.loglevel
      data.each do |key, value|
        logger.debug '-> %-20s %-20s' % [key, value]
      end
      # TODO set system timezone and update clock
    end

    def knock
      logger.info "Knocking..."
      url = @config.endpoint + '/' + identifier
      response = faraday.get(url)
      apply_config(JSON.parse(response.body))
    end

    def register
      logger.info "Registering..."
      uri = URI.parse(@config.endpoint)
      faraday.basic_auth(uri.user, uri.password)
      response = faraday.post(@config.endpoint, device: payload)
      if response.status != 200
        logger.warn "Registration failed.\n" + response.body
        logger.warn "Exiting..."
        exit
      end
      apply_config(JSON.parse(response.body))
      logger.info "Registration complete."
    end

    def display_pairing_instructions
      code = @config.pairing_code
      puts '*' * 60
      puts
      puts '             ***  HOW TO CLAIM THIS DEVICE  ***'
      puts
      puts 'Your pairing code is'
      puts
      system('toilet -f mono12 --gay " %s"' % code)
      puts
      puts 'Visit the following URL to claim this device.'
      puts
      puts '  https://voicerepublic.com/devices/%s' % code
      puts
      puts '*' * 60
    end

    def play_pairing_code
      Thread.new do
        url = @config.endpoint.sub('/api/devices', "/tts/#{@config.pairing_code}")
        system("curl -s -L #{url} > code.ogg")
        system("amixer -q set PCM 100%")
        while @config.state == 'pairing'
          system('ogg123 -q code.ogg')
          sleep 1.5
        end
      end
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

    def start_recording
      logger.info "Start backup recording..."
      FileUtils.mkdir_p 'recordings'
      cmd = "arecord -q -D #{@config.device} -f cd -t raw | " +
            'oggenc - -Q -r -o recordings/dump_`date +%s`.ogg'
      ResilientProcess.new(cmd, 'arecord', @config.check_record_interval, logger).run
    end

    def start_sync
      logger.info "Entering sync loop..."
      Thread.new do
        loop do
          logger.info 'Start syncing...'
          t0 = Time.now
          bucket, region = @config.storage['bucket'].split('@')
          cmd = "AWS_ACCESS_KEY_ID=#{@config.storage['aws_access_key_id']} " +
                "AWS_SECRET_ACCESS_KEY=#{@config.storage['aws_secret_access_key']} " +
                "aws s3 sync recordings s3://#{bucket}/#{identifier}" +
                " --region #{region} --quiet"
          logger.debug "Run: #{cmd}"
          system(cmd)
          logger.info 'Syncing completed in %.2fs. Next sync in %ss.' %
                      [Time.now - t0, @config.sync_interval]
          sleep @config.sync_interval
        end
      end
    end

    def run
      knock
      register
      if @config.state == 'pairing'
        display_pairing_instructions
        play_pairing_code
      end
      start_heartbeat
      start_reporting
      start_recording
      start_sync

      logger.info "Entering EM loop..."
      EM.run {
        self.client = Faye::Client.new(@config.faye_url)
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
      config = message['icecast'].merge(device: @config.device)
      write_config!(config)
      @streamer = ResilientProcess.new(stream_cmd,
                                       'darkice',
                                       @config.check_stream_interval,
                                       logger)
      @streamer.run
      logger.info "Started streaming."
      logger.debug config.inspect
      # HACK this makes the pairing code play loop stop
      @config.state = 'streaming'
    end

    # { event: 'stop_streaming' }
    def handle_stop_stream(message={})
      @streamer.stop!
      logger.info "Stopped streaming."
    end

    # { event: 'restart_streaming' }
    def handle_restart_stream(message={})
      @streamer.restart!
      logger.info "Restarted streaming."
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

    private

    def write_config!(config)
      File.open(config_path, 'w') { |f| f.write(render_config(config)) }
    end

    def render_config(config)
      # https://www.youtube.com/watch?v=MzlK0OGpIRs
      namespace = OpenStruct.new(config)
      bindink = namespace.instance_eval { binding }
      ERB.new(config_template).result(bindink)
    end

    def config_template
      File.read(File.expand_path(File.join(%w(.. .. .. darkice.cfg.erb)), __FILE__))
    end

    def stream_cmd
      "darkice -v 0 -c #{config_path} 2>&1 >/dev/null"
    end

    def config_path
      'darkice.cfg'
    end

  end
end
