# The ResilientProcess is resilient in two ways:
#
# * it will be restarted if its gone
# * it will survive a restart of the ruby process its spawned from
#
# Dev Note
#
# On the box you can watch the recordings grow:
#
#   watch ls -la streambox/recordings
#
module Streambox

  class ResilientProcess < Struct.new(:cmd, :pattern, :interval, :logger)

    def run
      # NOTE with multiple processes matching this will fail
      @pid = %x[pgrep #{pattern}].chomp.to_i

      Thread.new do
        loop do
          start unless exists?
          Process.wait(@pid)
        end
      end
    end

    private

    def start
      puts cmd
      logger.debug "RUN: #{cmd}"
      @pid = Process.spawn(cmd)
    end

    def exists?
      path = "/proc/#{@pid}"
      File.directory?(path)
    end

  end
end
