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

  class ResilientProcess < Struct.new(:cmd, :name, :interval, :logger)

    attr_accessor :running

    def run
      self.running = true
      @pidfile = "#{name}.pid"
      @pid = File.read(@pidfile).to_i if File.exist?(@pidfile)
      @pid = nil unless exists?

      if @pid
        logger.debug "Found pid #{@pid} for #{name}."
      else
        logger.debug "Found no pid for #{name}."
      end

      Thread.new do
        while running
          start unless exists?
          #logger.debug "Waiting for pid #{@pid} for #{name}"
          wait
        end
        logger.debug "ResilientProcess for #{name} is dead now."
      end
    end

    def stop!
      self.running = false
      kill
    end

    def restart!
      kill
      sleep interval
    end

    private

    def kill
      return if @pid.nil?
      logger.debug "Killing pid #{@pid}"
      File.unlink(@pidfile)
      _pid = @pid
      @pid = nil
      system("kill -HUP #{_pid}")
    end

    def start
      logger.debug "Run: #{cmd}"
      @pid = Process.spawn(cmd)
      File.open(@pidfile, 'w') { |f| f.print(@pid) }
      logger.debug "Pid for #{name} is #{@pid}"
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
      logger.debug "Not a child watching via procfs..."
      # otherwise we'll just check the procfs
      while exists?
        sleep interval
      end
    end

  end
end
