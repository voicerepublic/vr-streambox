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

    attr_accessor :running, :run_thread, :threads

    def initialize(cmd, name, interval, delay, logger)
      logger.debug "[RESILIENT] Init #{name}"

      self.cmd = cmd
      self.name = name
      self.interval = interval
      self.delay = delay
      self.logger = logger

      @pidfile = "../#{name}.pid"
      @pidilfe = File.expand_path(@pidfile, Dir.pwd)
      logger.debug "[RESILIENT] File: #{@pidilfe}"

      @pid = File.read(@pidfile).to_i if File.exist?(@pidfile)
      @pid = nil unless exists?

      self.threads = []

      if @pid
        logger.debug "[RESILIENT] Detected #{@pid} for #{name}. Resume running..."
        start!
      else
        logger.debug "[RESILIENT] No running process for #{name}, waiting for start."
      end
    end

    def start!
      logger.debug "[RESILIENT] ================================================== START!, running: #{running}"
      p @threads
      return if running

      self.running = true

      @start_counter ||= 0
      @start_counter += 1
      @thread_counter ||= 0

      if @pid
        logger.debug "[RESILIENT] Found #{@pid} for #{name}."
      else
        logger.debug "[RESILIENT] Found none for #{name}."
      end

      self.threads << Thread.new do
        @thread_counter += 1
        logger.debug "[RESILIENT] Start watching #{name}."
        start_new unless exists?
        while true
          logger.debug "[RESILIENT] ================================================== start: %s, thread: %s" %
                       [@start_counter, @thread_counter]
          start_new(delay) unless exists?
          #logger.debug "Waiting for pid #{@pid} for #{name}"
          wait
        end
        #logger.debug "[RESILIENT] Process for #{name} is dead now."
      end

      self
    end

    def stop!
      logger.debug "[RESILIENT] ================================================== STOP!"
      threads.last.kill
      if running
        kill!
      else
        logger.debug "[RESILIENT] Stop #{name} but not running. Attempt to kill all..."
        kill_all!
      end
      self.running = false
    end

    private

    def kill_all!
      system "killall #{name}"
    end

    def kill!
      return if @pid.nil?
      logger.debug "[RESILIENT] Killing pid #{@pid} and REMOVING PIDFILE!"
      File.unlink(@pidfile)
      _pid = @pid
      @pid = nil
      cmd = "kill -HUP -#{_pid}"
      logger.debug "[RESILIENT] Exec: #{cmd}"
      system(cmd)
    end

    def start_new(delay=0)
      sleep delay
      logger.debug "[RESILIENT] spawn: #{cmd}"
      @pid = Process.spawn(cmd, pgroup: true)
      File.open(@pidfile, 'w') { |f| f.print(@pid) }
      logger.debug "[RESILIENT] New pid for #{name} #{@pid}"
    end

    def exists?
      return false if @pid.nil?
      path = "/proc/#{@pid}"
      result = File.directory?(path)
      logger.debug "[RESILIENT] Stale pid #{@pid}?" unless result
      result
    end

    # sometimes dies here with `no implicit conversion from nil to integer`
    def wait
      # this will work if it is a child process
      Process.wait(@pid)
    rescue Errno::ECHILD
      logger.debug "[RESILIENT] Not a child watching via procfs..."
      # otherwise we'll just check the procfs
      while exists?
        sleep interval
      end
    end

  end
end
