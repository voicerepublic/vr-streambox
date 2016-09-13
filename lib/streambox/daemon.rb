# coding: utf-8
require 'logger'
require 'json'
require 'ostruct'
require 'uri'
require 'fileutils'
require 'erb'
require 'pp'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "fifo"
require "streambox/version"
require "streambox/reporter"
require "streambox/resilient_process"
require "streambox/banner"

# Test if an Icecast Server is Running on the given target
# curl -D - http://192.168.178.21:8000/ | grep Icecast

# TODO
# * start right away, do not check for network do not update
# * start recording
# * test if network is available, repeat until available
# * knocking should state which version is up to date
# * exit if update is required
# * after exit try to update if network is available
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
      # these are just defaults
      @config = OpenStruct.new endpoint: ENDPOINT,
                               loglevel: Logger::INFO,
                               device: 'dsnooped',
                               sync_interval: 60 * 10, # 10 minutes
                               check_record_interval: 1,
                               check_stream_interval: 1,
                               heartbeat_interval: 10,
                               reportinterval: 60,
                               restart_stream_delay: 2
      @reporter = Reporter.new
    end

    def identifier
      @reporter.serial
    end

    def payload
      {
        identifier:           identifier,
        type:                 'Streambox',
        subtype:              @reporter.subtype,
        private_ip_address:   @reporter.private_ip_address,
        mac_address_ethernet: @reporter.mac_address_ethernet,
        mac_address_wifi:     @reporter.mac_address_wifi,
        version:              @reporter.version
      }
    end

    def apply_config(data)
      #pp data

      data.each do |key, value|
        @config.send("#{key}=", value)
      end
      logger.level = @config.loglevel
      # TODO set system timezone and update clock

      # { "state"=>"starting_stream",
      #   "venue"=>{
      #     "name"=>"Phil Hofmann's Venue",
      #     "state"=>"awaiting_stream",
      #     "icecast"=>{
      #       "public_ip_address"=>"192.168.178.21",
      #       "source_password"=>"qyifjvpt",
      #       "mount_point"=>"live",
      #       "port"=>8000}}}


      version = data['version']
      #logger.debug "[VERSION] #{version} #{@reporter.version}"
      if version and version > @reporter.version
        logger.warn 'Version requirement not satetisfied. Exit, update & restart.'
        exit
      end

      if data['venue']
        state = data['venue']['state'].to_sym
        name = data['venue']['name']
        unless @state == state
          logger.debug '[STATE] %-30s -> %-20s' % [name, state.to_s.upcase]
          @state = state
        end

        # in certain states we have to react
        case state
        when :awaiting_stream, :disconnected
          handle_start_stream(data['venue'])
        when :disconnect_required, :offline, :available, :provisioning
          handle_stop_stream if @streamer
        end
      end

    end

    def knock
      logger.info "Knocking..."
      response = faraday.get(device_url)
      apply_config(JSON.parse(response.body))
      logger.info "Knocking complete."
    end

    def register
      logger.info "Registering..."
      uri = URI.parse(@config.endpoint)
      faraday.basic_auth(uri.user, uri.password)
      response = faraday.post(@config.endpoint, device: payload)
      if response.status != 200
        logger.warn "Registration failed with #{response.status}.\n" + response.body
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

    def start_publisher
      Thread.new do
        loop do
          until queue.empty?
            message = queue.first.last
            logger.debug "[EVENT] #{message.inspect}"
            put(device_url, message)
            self.queue.shift
          end
          sleep 0.1 # rate limited to 10 messages per second
        end
      end
    end

    def device_url
      [@config.endpoint, identifier] * '/'
    end

    def sound_device
      if %x[arecord -L | grep #{@config.device}].empty?
        logger.fatal "--- DEVICE #{@config.device} NOT FOUND, FALLBACK TO default ---"
        'default'
      else
        @config.device
      end
    end

    def heartbeat
      response = put(device_url)
      @network = response.status == 200
      if @prev_network != @network
        logger.warn "[NETWORK] #{@network ? 'UP' : 'DOWN'}"
        @prev_network = @network
      end
      json = JSON.parse(response.body)
      apply_config(json)
    end

    def start_observer(name)
      file = name + '.log'
      File.unlink(file) if File.exist?(file) and File.ftype(file) != 'fifo'

      logger.info "Start observer for #{name}..."
      fifo = Fifo.new(file)
      Thread.new do
        loop do
          line = fifo.gets
          logger.debug "[#{name.upcase}] #{line.chomp}"
        end
      end
    end

    def start_heartbeat
      logger.info "Start heartbeat..."
      Thread.new do
        loop do
          heartbeat
          sleep @config.heartbeat_interval
        end
      end
    end

    def report!
      response = put(device_url+'/report', @reporter.report)
      @network = response.status == 200
      if @prev_network != @network
        logger.warn "[NETWORK] #{@network ? 'UP' : 'DOWN'}"
        @prev_network = @network
      end
    end

    def start_reporting
      logger.info "Start reporting..."
      Thread.new do
        loop do
          report!
          sleep @config.report_interval
        end
      end
    end

    def start_recording
      logger.info "Start backup recording..."
      FileUtils.mkdir_p 'recordings'
      ResilientProcess.new(record_cmd,
                           'record.sh',
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
          system(sync_cmd)
          logger.info 'Syncing completed in %.2fs. Next sync in %ss.' %
                      [Time.now - t0, @config.sync_interval]
          sleep @config.sync_interval
        end
      end
    end

    def new_streamer!
      @streamer = ResilientProcess.new(stream_cmd,
                                       'darkice',
                                       @config.check_stream_interval,
                                       @config.restart_stream_delay,
                                       logger)
    end

    def run
      at_exit { fire_event :restart }

      logger.info "Id %s, IP %s, Version %s" %
                  [identifier,
                   @reporter.private_ip_address,
                   @reporter.version]

      start_recording
      knock
      logger.debug "Endpoint #{@config.endpoint}"
      start_heartbeat
      register
      start_publisher
      #start_reporting
      start_observer 'darkice'
      start_sync

      if @config.state == 'pairing'
        display_pairing_instructions
        play_pairing_code
      else
        Banner.new
      end

      if File.exist?('../darkice.pid')
        new_streamer!
        #fire_event :found_streaming
      end

      # logger.info "Entering EM loop..."
      # EM.run {
      #   self.client = Faye::Client.new(@config.faye_url)
      #   ext = Faye::Authentication::ClientExtension.new(@config.faye_secret)
      #   client.add_extension(ext)
      #
      #   multi_io.add(FayeIO.new(client, identifier)) if @config.loglevel == 0
      #
      #   logger.debug "[FAYE] Subscribing to channel '#{channel}'..."
      #
      #   self.subscription = client.subscribe(channel) { |message| dispatch(message) }
      #
      #   subscription.callback do
      #     logger.debug "[FAYE] Subscribe succeeded."
      #   end
      #
      #   subscription.errback do |error|
      #     logger.warn "Failed to subscribe with #{error.inspect}."
      #   end
      #
      #   client.bind 'transport:down' do
      #     logger.warn "Connection DOWN. Expecting reconnect..."
      #     @awaiting_connection = Time.now
      #     Thread.new do
      #       while @awaiting_connection
      #         delta = Time.now - @awaiting_connection
      #         if delta > 60
      #           logger.warn "Connection DOWN for over 60 seconds now. Restarting..."
      #           exit
      #         else
      #           logger.debug "[FAYE] Connection DOWN for %.0f seconds now." % delta
      #         end
      #         sleep 1
      #       end
      #     end
      #   end
      #
      #   client.bind 'transport:up' do
      #     unless @awaiting_connection.nil?
      #       delta = Time.now - @awaiting_connection
      #       logger.warn "Connection UP. Was down for %.2f seconds." % delta
      #       @awaiting_connection = nil
      #     end
      #   end
      #
      #   publish event: 'print', print: 'Device ready.'
      # }
      loop do
        sleep 5
      end

      logger.warn "Exiting."
    end

    # TODO maybe rewrite handle_ methods to not use arguments
    def dispatch(message={})
      logger.debug "[FAYE] Received #{message.inspect}"
      method = "handle_#{message['event']}"
      return send(method, message) if respond_to?(method)
      publish event: 'error', error: "Unknown message: #{message.inspect}"
    end

    # { event: 'start_streaming', icecast: { ... } }
    def handle_start_stream(message={})
      logger.info "Starting stream..."
      config = message['icecast'].merge(device: sound_device)
      write_config!(config)
      @streamer and @streamer.stop!
      new_streamer!
      @streamer.run
      # HACK this makes the pairing code play loop stop
      @config.state = 'running'
      fire_event :stream_started
    end

    # { event: 'stop_streaming' }
    def handle_stop_stream(message={})
      logger.info "Stopping stream..."
      @streamer && @streamer.stop!
      @streamer = nil
      fire_event :stream_stopped
    end

    # { event: 'eval', eval: '41+1' }
    def handle_eval(message={})
      code = message['eval']
      logger.debug "[FAYE] Eval: #{code}"
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
      logger.debug "[FAYE] Print: #{message['print']}"
    end

    # obsolete
    def handle_heartbeat(message={})
      # ignore
    end

    # obsolete
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
      "DEVICE=%s ./record.sh" % sound_device
    end

    def sync_cmd
      bucket, region = @config.storage['bucket'].split('@')
      vars = {
        AWS_ACCESS_KEY_ID: @config.storage['aws_access_key_id'],
        AWS_SECRET_ACCESS_KEY: @config.storage['aws_secret_access_key'],
        BUCKET: bucket,
        IDENTIFIER: identifier,
        REGION: region
      }
      vars = vars.map { |v| v * '=' } * ' ' # ¯\_(ツ)_/¯
      "%s ./sync.sh" % vars
    end

    def config_path
      'darkice.cfg'
    end

    def fire_event(event)
      self.queue << ['/event/devices', {event: event, identifier: identifier}]

      #uri = URI.parse(@config.endpoint + '/' + identifier)
      #faraday.basic_auth(uri.user, uri.password)
      #response = faraday.post(@config.endpoint, device: { event: event })
      #logger.warn "Firing event failed.\n" + response.body if response.status != 200
    end

  end
end
