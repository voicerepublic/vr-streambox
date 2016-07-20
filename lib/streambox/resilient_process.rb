# The ResilientProcess is resilient in two ways:
#
# * it will be restarted if its gone
# * it will survive a restart of the ruby process its spawned from
#
module Streambox

  class ResilientProcess < Struct.new(:cmd, :pattern, :interval, :logger)

    def run
      @pid = system("pgrep #{pattern}")

      Thread.new do
        loop do
          start unless exists?(@pid)
          sleep interval
        end
      end
    end

    private

    def start
      logger.debug "RUN: #{cmd}"
      @pid = Process.spawn(cmd)
    end

    def exists?(pid)
      return false unless pid
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end

  end
end
