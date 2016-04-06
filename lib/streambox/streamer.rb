require 'erb'

module Streambox
  class Streamer < Struct.new(:config)

    def start_streaming!
      write_config!
      @thread = Thread.new do
        system stream_cmd
      end
    end

    def stop_streaming!
      @thread.stop
    end

    private

    def write_config!
      ERB.new(config_template).result(config.binding)
    end

    def config_template
      File.read(File.expand_path(File.join(%w(.. .. .. darkice.cfg.erb)), __FILE__))
    end

    def stream_cmd
      # uses sudo to make use of posix realtime scheduling
      'sudo darkice -c darkice.cfg'
    end

  end
end
