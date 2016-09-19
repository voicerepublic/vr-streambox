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

  class ResilientProcess

    attr_accessor :cmd, :name, :interval, :delay, :logger

    attr_accessor :running

    def initialize(cmd, name, interval, delay, logger)
      self.cmd = cmd
      self.name = name
      self.interval = interval
      self.delay = delay
      self.logger = logger

      @pidfile = "../#{name}.pid"
      @pidilfe = File.expand_path(@pidfile, Dir.pwd)
      logger.debug "[PID] File: #{@pidilfe}"

      @pid = File.read(@pidfile).to_i if File.exist?(@pidfile)
      @pid = nil unless exists?

      if @pid
        logger.debug "[PID] Detected #{@pid} for #{name}. Resume running..."
        run
      end
    end

    def run
      self.running = true

      if @pid
        logger.debug "[PID] Found #{@pid} for #{name}."
      else
        logger.debug "[PID] Found none for #{name}."
      end

      Thread.new do
        logger.debug "[PID] Start watching #{name}."
        start unless exists?
        while running
          start(delay) unless exists?
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
    end

    def kill_all!
      self.running = false
      system "killall #{name}"
    end

    private

    def kill
      return if @pid.nil?
      logger.debug "Killing pid #{@pid}"
      File.unlink(@pidfile)
      _pid = @pid
      @pid = nil
      cmd = "kill -HUP -#{_pid}"
      logger.debug "Exec: #{cmd}"
      system(cmd)
    end

    def start(delay=0)
      sleep delay
      #logger.debug "Run: #{cmd}"
      @pid = Process.spawn(cmd, pgroup: true)
      File.open(@pidfile, 'w') { |f| f.print(@pid) }
      logger.debug "[PID] #{name} #{@pid}"
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
