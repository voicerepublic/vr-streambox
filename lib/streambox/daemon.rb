# coding: utf-8
require 'logger'
require 'json'
require 'ostruct'
require 'uri'
require 'fileutils'
require 'erb'
require 'pp'
require 'net/http'

require 'faraday'
require 'rb-inotify'

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

  class Daemon

    ENDPOINT = 'https://voicerepublic.com/api/devices'

    attr_accessor :queue, :recorder, :recordings, :bandwidth

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
                               restart_stream_delay: 5
      @reporter = Reporter.new
    end

    def identifier
      @reporter.serial
    end

    def register_payload
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
      pp data

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
        logger.debug '[STATE] local: %s, remote: %s' % [@state.to_s.upcase,
                                                        state.to_s.upcase]
        unless @state == state
          logger.debug '[STATE] %-30s -> %-20s' % [name, state.to_s.upcase]
          @state = state
        end

        # in certain states we have to react
        case state
        when :awaiting_stream, :disconnected
          handle_start_stream(data['venue'])
        when :disconnect_required
          @streamer.stop!
        end
      end

    end

    def knock!
      response = faraday.get(device_url)
      apply_config(JSON.parse(response.body))

    rescue Faraday::TimeoutError
      logger.fatal "Error: Knocking timed out."
      exit
    rescue Faraday::ConnectionFailed
      logger.fatal "Error: The internet connection seems to be down. Retry in 10s..."
      sleep 10
      retry
    end

    def register!
      uri = URI.parse(@config.endpoint)
      faraday.basic_auth(uri.user, uri.password)
      response = faraday.post(@config.endpoint, device: register_payload)
      if response.status != 200
        logger.warn "Registration failed with #{response.status}.\n" + response.body
        logger.warn "Exiting..."
        exit
      end
      apply_config(JSON.parse(response.body))

    rescue Faraday::TimeoutError
      logger.fatal "Error: Register timed out."
      exit
    rescue Faraday::ConnectionFailed
      logger.fatal "Error: The internet connection seems to be down."
      exit
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
            message = queue.first
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
      t0 = Time.now
      response = put(device_url)
      @dt = Time.now - t0
      #logger.debug 'Heartbeat responded in %.3fs' % @dt
      @network = response.status == 200
      if @prev_network != @network
        logger.warn "[NETWORK] #{@network ? 'UP' : 'DOWN'}"
        @prev_network = @network
      end
      json = JSON.parse(response.body)
      apply_config(json)
    rescue Faraday::TimeoutError
      logger.error "Error: Heartbeat timed out."
    rescue JSON::ParserError
      logger.error "Error: Heartbeat could not parse JSON."
    end

    def start_observer(name)
      file = name + '.log'
      File.unlink(file) if File.exist?(file) and File.ftype(file) != 'fifo'

      fifo = Fifo.new(file)
      Thread.new do
        loop do
          line = fifo.gets
          logger.debug "[#{name.upcase}] #{line.chomp}"

          if line.match(/mountpoint occupied, or maximum sources reached/)
            logger.debug "Two resilitent process for darkice running?"
          end

          if line.match(/sox WARN alsa: No such device/)
            recorder.stop!
            puts
            system 'toilet -f mono12 "Shutdown"'
            puts
            puts "Shutdown after sync..."
            sync
            system 'shutdown -h now'
          end

          if line.match(/RequestTimeTooSkewed/)
            system './sync_clock.sh'
            sync # extra sync after clock is fixed
          end

          if line.match(/Darkice: TcpSocket.cpp:251: connect error \[111\]/)
            # handle lots of defunct processes
          end
        end
      end
    end

    def start_heartbeat
      Thread.new do
        loop do
          heartbeat
          sleep @config.heartbeat_interval
        end
      end
    end

    def report!
      more = {
        heartbeat_response_time: @dt,
        recordings: recordings,
        bandwidth: bandwidth,
        now: Time.now
      }
      report = more.merge(@reporter.report)
      response = put(device_url+'/report', report)
      @network = response.status == 200
      if @prev_network != @network
        logger.warn "[NETWORK] #{@network ? 'UP' : 'DOWN'}"
        @prev_network = @network
      end
    rescue Faraday::TimeoutError
      logger.error "Error: Reporting timed out."
    end

    def start_reporting
      Thread.new do
        loop do
          report!
          sleep @config.report_interval
        end
      end
    end

    def start_recording
      self.recorder = ResilientProcess.new(record_cmd,
                                       'record.sh',
                                       @config.check_record_interval,
                                       0,
                                       logger).start!
    end

    def start_recording_monitor
      notifier = INotify::Notifier.new
      events = [:create, :delete, :close_write, :modify]
      self.recordings = {}

      notifier.watch('../recordings', *events) do |event|

        unless event.flags == [:modify]
          logger.debug event.flags.inspect + ' ' + event.name
        end

        name = event.name
        self.recordings[name] ||= {}

        case event.flags
        when [:modify]
          self.recordings[name][:first_updated] ||= Time.now
          self.recordings[name][:last_updated] = Time.now
          self.recordings[name][:size] = File.size(event.absolute_name)
        when [:close_write, :close]
          self.recordings[name][:closed] ||= Time.now
        when [:create]
          self.recordings[name][:created] = Time.now
        when [:delete]
          self.recordings[name][:deleted] = Time.now
        end

        # puts recordings.to_yaml
      end

      Thread.new do
        notifier.run
      end
    end

    def sync
      total = 0
      Dir.glob('../recordings/*.ogg').each do |path|
        total += File.size(path)
      end

      logger.info 'Start syncing %.2fkb...' % (total/1024)

      t0 = Time.now
      system(sync_cmd)
      dt = Time.now - t0
      self.bandwidth = total / dt # in bytes per second
      logger.info 'Syncing completed in %.2fs at %.2fkbps. Next sync in %ss.' %
                  [dt, bandwidth/1024, @config.sync_interval]

    end

    def start_sync
      Thread.new do
        loop do
          sync
          sleep @config.sync_interval
        end
      end
    end

    def start_streamer
      @streamer = ResilientProcess.new(stream_cmd,
                                       'darkice',
                                       @config.check_stream_interval,
                                       @config.restart_stream_delay,
                                       logger)
    end

    def special_check_for_reboot_required
      unless File.symlink?('/home/pi/streambox')
        logger.warn "Reboot required!"
        system 'reboot'
      end
    end

    def run
      at_exit { fire_event :restart }

      @config.loglevel = Logger::DEBUG if dev_box?

      special_check_for_reboot_required

      logger.info "Id %s, IP %s, Version %s" %
                  [identifier,
                   @reporter.private_ip_address,
                   @reporter.version]

      logger.info "[0] Start recording..."
      start_recording

      logger.info "[1] Start recording monitor..."
      start_recording_monitor

      logger.info "[2] Start observers..."
      start_observer 'record'
      start_observer 'sync'
      start_observer 'darkice'

      logger.info "[3] Knocking..."
      knock!
      logger.info "[4] Knocking complete."
      logger.debug "Endpoint #{@config.endpoint}"

      logger.info "[5] Start Streamer..."
      start_streamer
      logger.info "[6] Streamer started."

      if dev_box?
        logger.warn "[7] Dev Box detected! Skipping check for release."
      else
        logger.warn "[7] Checking for release..."
        check_for_release
      end

      logger.info "[8] Registering..."
      register!
      logger.info "[9] Registration complete."

      logger.info "[A] Start heartbeat..."
      start_heartbeat

      logger.info "[B] Start reporting..."
      start_reporting

      logger.info "[C] Start publisher..."
      start_publisher

      logger.info "[D] Start sync loop..."
      start_sync

      if @config.state == 'pairing'
        display_pairing_instructions
        play_pairing_code
      else
        Banner.new
      end

      loop do
        sleep 5
      end

      logger.warn "Exiting."
    end

    # { event: 'start_streaming', icecast: { ... } }
    def handle_start_stream(message={})
      logger.info "Starting stream..."
      config = message['icecast'].merge(device: sound_device)
      write_config!(config)
      @streamer.stop!
      @streamer.start!
      # HACK this makes the pairing code play loop stop
      @config.state = 'running'
      fire_event :stream_started
    end

    # # { event: 'eval', eval: '41+1' }
    # def handle_eval(message={})
    #   code = message['eval']
    #   logger.debug "Eval: #{code}"
    #   output = eval(code)
    # rescue => e
    #   output = 'Error: ' + e.message
    # ensure
    #   publish event: 'print', print: output.inspect
    # end

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

    rescue Faraday::ConnectionFailed
      logger.fatal "Error: The internet connection seems to be down."
      exit
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
      self.queue << { event: event, identifier: identifier }
    end

    def dev_box?
       File.exist?('/boot/dev_box')
    end

    def check_for_release
      response = faraday.get 'https://voicerepublic.com/versions/streamboxx'
      version = response.body.to_i

      logger.debug 'Installed release %s, announced release %s.' %
                   [@reporter.version, version]

      if version > @reporter.version
        logger.info 'Newer release available. Updating...'
        install_release(@reporter.version, version)
      else
        logger.info 'Already up-to-date.'
      end
    end

    def install_release(from, to)
      system "./install_release.sh"

      id_link = slack_link(identifier, SLACK_LINK + identifier)
      slack('Upgraded Streamboxx %s from v%s to v%s.' % [id_link, from, to])

      if reboot_required?(from, to)
        logger.warn 'Rebooting...'
        system 'reboot'
        return
      end

      logger.warn 'Exit for restart...'
      exit
    end

    # this only works for releases
    def reboot_required?(from, to)
      return true if from == 27

      false
    end

    SLACK_HOOK = 'https://hooks.slack.com/services/'+
                 'T02CS5YFX/B0NL4U5B9/uG5IExBuAnRjC0H56z2R1WXG'

    SLACK_LINK = 'https://voicerepublic.com:444/admin/devices/'

    def slack_link(text, url)
      '<%s|%s>' % [url, text]
    end

    def slack(msg)
      payload = {
        channel: '#streamboxx',
        username: 'streamboxx',
        icon_emoji: ':sparkles:',
        text: msg
      }
      uri = URI(SLACK_HOOK)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      request = Net::HTTP::Post.new(uri.path)
      request.body = JSON.unparse(payload)
      https.request(request)
    end

  end
end
