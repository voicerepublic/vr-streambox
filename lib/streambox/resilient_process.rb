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

    attr_accessor :running

    def run
      self.running = true
      @pidfile = "#{pattern}.pid"
      @pid = File.read(@pidfile).to_i if File.exist?(@pidfile)
      if @pid
        logger.debug "Found pid #{@pid} (#{name}) for #{pattern}."
      else
        logger.debug "Found no pid for #{pattern}."
      end

      Thread.new do
        while running
          start unless exists?
          logger.debug "Waiting for pid #{@pid} (#{name}) for #{pattern}"
          wait
        end
        logger.debug "ResilientProcess for #{pattern} is dead now."
      end
    end

    def stop!
      self.running = false
      kill
    end

    def restart!
      kill
    end

    private

    def kill
      return if @pid.nil?
      logger.debug "Killing pid #{@pid} (#{name})"
      system("kill -HUP #{@pid}")
      File.unlink(@pidfile)
    end

    def name
      return '-' if @pid.nil?
      %x[ps -p #{@pid} -o comm=].chomp
    end

    def start
      logger.debug "Run: #{cmd}"
      @pid = Process.spawn(cmd)
      File.open(@pidfile, 'w') { |f| f.print(@pid) }
      logger.debug "Pid is #{@pid} (#{name})"
    end

    def exists?
      return false if @pid.nil?
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
