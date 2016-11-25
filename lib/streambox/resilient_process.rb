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

    attr_accessor :watchdog

    def initialize(cmd, name, interval, delay, logger)
      logger.debug "[RESILIENT] init: #{name}"

      self.cmd = cmd
      self.name = name
      self.interval = interval
      self.delay = delay
      self.logger = logger

      @pidfile = "../#{name}.pid"
      @pidilfe = File.expand_path(@pidfile, Dir.pwd)
      logger.debug "[RESILIENT] init: File: #{@pidilfe}"

      @pid = File.read(@pidfile).to_i if File.exist?(@pidfile)
      @pid = nil unless exists?

      if @pid
        logger.debug "[RESILIENT] init: Detected #{@pid} for #{name}. Resume running..."
        start!
      else
        logger.debug "[RESILIENT] init: No running process for #{name}, waiting for start."
      end
    end

    def start!
      logger.debug "[RESILIENT] start!: ================================================== START!, watchdog: #{watchdog}"
      # guard against multiple runs in paralell
      if watchdog and watchdog.alive?
        logger.debug "[RESILIENT] start!: Abort start, found a watchdog running."
        return
      end

      @start_counter ||= 0
      @start_counter += 1
      @thread_counter ||= 0

      if @pid
        logger.debug "[RESILIENT] start!: Found #{@pid} for #{name}."
      else
        logger.debug "[RESILIENT] start!: Found none for #{name}."
      end

      # FIXME IT HANGS HERE SOMETIMES
      logger.debug "[RESILIENT] start!: Setup new watchdog..."
      self.watchdog = Thread.new do
        @thread_counter += 1
        logger.debug "[RESILIENT] start!: Start watching #{name}."
        #start_new unless exists?
        @cycle_counter = 0
        while true
          @cycle_counter += 1
          logger.debug "[RESILIENT] start!: ================================================== start: %s, thread: %s, cycle: %s" %
                       [@start_counter, @thread_counter, @cycle_counter]
          start_new unless exists?
          #logger.debug "Waiting for pid #{@pid} for #{name}"
          wait
          sleep delay
        end
        #logger.debug "[RESILIENT] Process for #{name} is dead now."
      end

      self
    end

    def stop!
      logger.debug "[RESILIENT] stop!: ================================================== STOP!"
      if watchdog and watchdog.alive?
        logger.debug "[RESILIENT] stop!: Killing watchdog..."
        watchdog.kill
        logger.debug "[RESILIENT] stop!: Killed the watchdog."
        if @pid
          logger.debug "[RESILIENT] stop!: Killing process #{@pid}..."
          kill!
          logger.debug "[RESILIENT] stop!: Killed it."
        else
          logger.debug "[RESILIENT] stop!: Stop #{name} but no pid. Attempt to kill all..."
          kill_all!
        end
      else
        logger.debug "[RESILIENT] stop!: Stop #{name} but no watchdog. Attempt to kill all..."
        kill_all!
      end
    end

    private

    def kill_all!
      system "killall #{name}"
    end

    def kill!
      if @pid.nil?
        logger.debug "[RESILIENT] kill!: Kill what? The pid is nil!"
        return
      end
      logger.debug "[RESILIENT] kill!: Killing pid #{@pid} and REMOVING PIDFILE!"
      File.unlink(@pidfile)
      _pid = @pid
      @pid = nil
      cmd = "kill -HUP -#{_pid}"
      logger.debug "[RESILIENT] kill!: exec: #{cmd}"
      system(cmd)
    end

    def start_new
      logger.debug "[RESILIENT] start_new: spawn: #{cmd}"
      @pid = Process.spawn(cmd, pgroup: true)
      File.open(@pidfile, 'w') { |f| f.print(@pid) }
      logger.debug "[RESILIENT] start_new: New pid for #{name} #{@pid}"
    end

    def exists?
      return false if @pid.nil?
      path = "/proc/#{@pid}"
      result = File.directory?(path)
      logger.debug "[RESILIENT] exists?: Stale pid #{@pid}?" unless result
      result
    end

    # sometimes dies here with `no implicit conversion from nil to integer`
    def wait
      # this will work if it is a child process
      logger.debug "[RESILIENT] wait: Waiting for process #{@pid}."
      Process.wait(@pid)
      logger.debug "[RESILIENT] wait: Process #{@pid} gone."
    rescue Errno::ECHILD
      logger.debug "[RESILIENT] wait: Process #{@pid} is not a child. Observing procfs..."
      # otherwise we'll just check the procfs
      while exists?
        sleep interval
      end
    end

  end
end
