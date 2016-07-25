require 'erb'
require 'ostruct'

module Streambox
  class Streamer

    attr_accessor :config, :logger

    def initialize(logger)
      self.logger = logger
      @pid = %x[pgrep darkice].to_i
      logger.debug "OLD DARKICE PID: #{@pid}"
      @pid = nil if !!@pid
    end

    def start!(config=nil)
      self.config = config if config
      write_config!
      stop!
      @pid = Process.spawn(stream_cmd)
      logger.debug "NEW DARKICE PID: #{@pid}"
      @pid
    end

    def stop!
      logger.debug "STOP PID: #{@pid}"
      return unless @pid
      logger.debug "SEND HUP: #{@pid}"
      logger.debug "PROCESS NAME: " + %x[ps -p #{@pid} -o comm=]
      Process.kill 'HUP', @pid
      logger.debug "WAIT FOR: #{@pid}"
      Process.wait
      @pid = nil
    end

    # obsolete?
    def restart!
      stop!
      start!
    end

    # required?
    def force_stop!
      %x[ killall darkice ]
    end

    private

    def write_config!
      File.open(config_path, 'w') { |f| f.write(render_config) }
    end

    def render_config
      # https://www.youtube.com/watch?v=MzlK0OGpIRs
      namespace = OpenStruct.new(config)
      bindink = namespace.instance_eval { binding }
      ERB.new(config_template).result(bindink)
    end

    def config_template
      File.read(File.expand_path(File.join(%w(.. .. .. darkice.cfg.erb)), __FILE__))
    end

    def stream_cmd
      # uses sudo to make use of posix realtime scheduling
      "darkice -v 0 -c #{config_path} 2>&1 >/dev/null"
    end

    def config_path
      'darkice.cfg'
    end

  end
end
