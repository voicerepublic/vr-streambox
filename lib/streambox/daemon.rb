require 'logger'
require 'json'
require 'ostruct'
require 'uri'
require 'fileutils'
require 'erb'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "streambox/version"
require "streambox/reporter"
require "streambox/resilient_process"
require "streambox/banner"

# Test if an Icecast Server is Running on the given target
# curl -D - http://192.168.178.21:8000/ | grep Icecast

# TODO introduce a proper state machine
module Streambox

  class MultiIO
    def initialize(*targets)
      @targets = targets
    end

    def write(*args)
      @targets.each {|t| t.write(*args)}
    end

    def close
      @targets.each(&:close)
    end

    def add(target)
      @targets << target
    end
  end

  class FayeIO < Struct.new(:client, :identifier)

    def write(*args)
      client.publish("/device/log/#{identifier}", log: args.first.chomp)
    end

    def close
      client.publish("/device/log/#{identifier}", log: 'closed.')
    end

  end

  class Daemon

    ENDPOINT = 'https://voicerepublic.com/api/devices'

    attr_accessor :client, :subscription, :queue

    def initialize
      Thread.abort_on_exception = true
      @queue = []
      @config = OpenStruct.new endpoint: ENDPOINT,
                               loglevel: Logger::INFO,
                               device: 'dsnooped',
                               sync_interval: 60 * 10, # 10 minutes
                               check_record_interval: 1,
                               check_stream_interval: 1,
                               restart_stream_delay: 2
      @reporter = Reporter.new
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
      pp data

      #device_state = data['state']
      #venue_state = data['venue']['state']
      #logger.debug '%-20s %-20s %-20s' % [identifier, device_state, venue_state]

      # { "state"=>"starting_stream",
      #   "venue"=>{
      #     "name"=>"Phil Hofmann's Venue",
      #     "state"=>"awaiting_stream",
      #     "icecast"=>{
      #       "public_ip_address"=>"192.168.178.21",
      #       "source_password"=>"qyifjvpt",
      #       "mount_point"=>"live",
      #       "port"=>8000}}}
      case data['state']
      when 'starting_stream'
        handle_start_stream(data['venue'])
      when 'restarting_stream'
        handle_restart_stream(data['venue'])
      when 'stopping_stream'
        handle_stop_stream(data['venue'])
      when 'streaming'
        if data['venue']['state'] == 'disconnected'
          logger.warn "Detected: Streaming, but venue still disconnected!"
          handle_restart_stream(data['venue'])
        end
      end

      data.each do |key, value|
        @config.send("#{key}=", value)
      end
      logger.level = @config.loglevel

      #data.each do |key, value|
      #  logger.debug '-> %-20s %-20s' % [key, value]
      #end
      # TODO set system timezone and update clock
    end

    def knock
      logger.info "Knocking..."
      url = @config.endpoint + '/' + identifier
      response = faraday.get(url)
      apply_config(JSON.parse(response.body))

      @config.each do |key, value|
        logger.debug '-> %-20s %-20s' % [key, value]
      end
      logger.info "Knocking complete."
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

      @config.each do |key, value|
        logger.debug '-> %-20s %-20s' % [key, value]
      end
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

    def start_publisher
      Thread.new do
        loop do
          if client.nil?
            sleep 1
          else
            until queue.empty?
              # client.publish(*queue.first)
              message = queue.first.last
              put(device_url, message)
              self.queue.shift
            end
            sleep 0.1
          end
        end
      end
    end

    def device_url
      @device_url ||= [@config.endpoint, identifier] * '/'
    end

    def sound_device
      if %x[arecord -L | grep #{@config.device}].empty?
        logger.fatal "--- DEVICE #{@config.device} NOT FOUND, FALLBACK TO default ---"
        'default'
      else
        @config.device
      end
    end

    def start_heartbeat
      logger.info "Start heartbeat..."
      Thread.new do
        loop do
          sleep @config.heartbeat_interval
          response = put(device_url)
          json = JSON.parse(response.body)
          apply_config(json)
          # if client.nil?
          #   logger.warn "Skip heartbeat. Client not ready."
          # else
          #   client.publish '/heartbeat', {
          #                    identifier: identifier,
          #                    interval: @config.heartbeat_interval
          #                  }
          # end
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
      ResilientProcess.new(record_cmd,
                           'arecord',
                           @config.check_record_interval,
                           0,
                           logger).run
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

    def streamer
      @streamer ||= ResilientProcess.new(stream_cmd,
                                         'darkice',
                                         @config.check_stream_interval,
                                         @config.restart_stream_delay,
                                         logger)
    end

    def run
      at_exit { fire_event :restart }
      knock
      register
      if @config.state == 'pairing'
        display_pairing_instructions
        play_pairing_code
      else
        Banner.new
      end
      start_publisher
      start_heartbeat
      start_reporting
      start_recording
      start_sync
      if File.exist?('darkice.pid')
        streamer.run
        fire_event :stream_started
      end

      logger.info "Entering EM loop..."
      EM.run {
        self.client = Faye::Client.new(@config.faye_url)
        ext = Faye::Authentication::ClientExtension.new(@config.faye_secret)
        client.add_extension(ext)

        multi_io.add(FayeIO.new(client, identifier)) if @config.loglevel == 0

        logger.debug "Subscribing to channel '#{channel}'..."

        self.subscription = client.subscribe(channel) { |message| dispatch(message) }

        subscription.callback do
          logger.debug "Subscribe succeeded."
        end

        subscription.errback do |error|
          logger.warn "Failed to subscribe with #{error.inspect}."
        end

        client.bind 'transport:down' do
          logger.warn "Connection DOWN. Expecting reconnect..."
          @awaiting_connection = Time.now
          Thread.new do
            while @awaiting_connection
              delta = Time.now - @awaiting_connection
              if delta > 60
                logger.warn "Connection DOWN for over 60 seconds now. Restarting..."
                exit
              else
                logger.debug "Connection DOWN for %.0f seconds now." % delta
              end
              sleep 1
            end
          end
        end

        client.bind 'transport:up' do
          unless @awaiting_connection.nil?
            delta = Time.now - @awaiting_connection
            logger.warn "Connection UP. Was down for %.2f seconds." % delta
            @awaiting_connection = nil
          end
        end

        publish event: 'print', print: 'Device ready.'
      }
      logger.warn "Exiting."
    end

    # TODO maybe rewrite handle_ methods to not use arguments
    def dispatch(message={})
      logger.debug "Received #{message.inspect}"
      method = "handle_#{message['event']}"
      return send(method, message) if respond_to?(method)
      publish event: 'error', error: "Unknown message: #{message.inspect}"
    end

    # { event: 'start_streaming', icecast: { ... } }
    def handle_start_stream(message={})
      logger.info "Starting stream..."
      config = message['icecast'].merge(device: sound_device)
      write_config!(config)
      streamer.stop!
      streamer.run
      logger.debug config.inspect
      # HACK this makes the pairing code play loop stop
      @config.state = 'streaming'
      fire_event :stream_started
    end

    # { event: 'stop_streaming' }
    def handle_stop_stream(message={})
      logger.info "Stopping stream..."
      streamer.stop!
      fire_event :stream_stopped
    end

    # { event: 'restart_streaming' }
    def handle_restart_stream(message={})
      logger.info "Restarting stream..."
      system('killall darkice')
      #streamer.restart!
      fire_event :stream_restarted
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
      fire_event :shutdown
      %x[ sudo shutdown -h now ]
    end

    def handle_reboot(message={})
      logger.info "Rebooting..."
      fire_event :restart
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

    def multi_io
      @multi_io ||= MultiIO.new(STDOUT)
    end

    def logger
      @logger ||= Logger.new(multi_io).tap do |logger|
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

    def put(url, data={})
      uri = URI.parse(url)
      faraday.basic_auth(uri.user, uri.password)
      faraday.put(url, data)
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
      "darkice -c #{config_path} 2>&1 > darkice.log"
    end

    def record_cmd
      "arecord -q -D #{sound_device} -f cd -t raw | " +
        'oggenc - -Q -r -o recordings/dump_`date +%s`.ogg'
    end

    def config_path
      'darkice.cfg'
    end

    def fire_event(event)
      logger.debug ">>>>> #{event}"
      self.queue << ['/event/devices', {event: event, identifier: identifier}]

      #uri = URI.parse(@config.endpoint + '/' + identifier)
      #faraday.basic_auth(uri.user, uri.password)
      #response = faraday.post(@config.endpoint, device: { event: event })
      #logger.warn "Firing event failed.\n" + response.body if response.status != 200
    end

  end
end
