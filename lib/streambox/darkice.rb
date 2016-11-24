require 'rb-inotify'
# require 'fifo'
require 'fileutils'

module Streambox
  class Darkice

    EVENTS     = [:delete, :close_write]
    CONFIG     = 'darkice.cfg'
    LOG        = 'darkice.log'
    LAUNCH_CMD = 'darkice -c %s 2>&1 > %s' % [CONFIG, LOG]
    KILL_CMD   = 'killall -9 darkice'

    def run
      # File.unlink(LOG) if File.exist?(LOG) and File.ftype(LOG) != 'fifo'
      #
      # fifo = Fifo.new(LOG)
      # @log = Thread.new do
      #   loop do
      #     line = fifo.gets.chomp
      #     puts line
      #     if line.match(/mountpoint occupied, or maximum sources reached/)
      #       logger.debug "Two resilitent process for darkice running?"
      #     end
      #
      #     if line.match(/Darkice: TcpSocket.cpp:251: connect error \[111\]/)
      #       # handle lots of defunct processes
      #     end
      #   end
      # end

      #File.unlink(CONFIG) if File.exist?(CONFIG)
      start if File.exist?(CONFIG)

      @notifier = INotify::Notifier.new
      @notifier.watch('.', *EVENTS) { |event| changed(event) }

      @notifier.run
      #@log.join
    end

    def changed(event)
      return if event.name != CONFIG
      event.flags.each do |flag|
        case flag
        when :close_write then start
        when :delete then stop
        end
      end
    end

    def start
      stop
      #puts LAUNCH_CMD
      system LAUNCH_CMD
    end

    def stop
      #puts KILL_CMD
      system KILL_CMD
    end

  end

end

Streambox::Darkice.new.run if __FILE__ == $0
