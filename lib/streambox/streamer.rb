require 'erb'
require 'ostruct'

module Streambox
  class Streamer < Struct.new(:config)

    def start_streaming!
      write_config!
      @thread = Thread.new do
        system stream_cmd
      end
    end

    def stop_streaming!
      @thread.exit
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
      "sudo darkice -c #{config_path}"
    end

    def config_path
      'darkice.cfg'
    end

  end
end
