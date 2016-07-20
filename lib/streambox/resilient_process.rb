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
      output = %x[pgrep #{pattern}]
      @pid = output.chomp.to_i

      Thread.new do
        loop do
          start unless exists?
          logger.debug "Waiting for pid #{@pid} (#{pattern})"
          wait
        end
      end
    end

    private

    def start
      logger.debug "RUN: #{cmd}"
      @pid = Process.spawn(cmd)
    end

    def exists?
      return false unless @pid
      path = "/proc/#{@pid}"
      File.directory?(path)
    end

    def wait
      # this will work if it is a child process
      Process.wait(@pid)
    rescue Errno::ECHILD
      # otherwise we'll just check the procfs
      while exists?
        sleep interval
      end
    end

  end
end
