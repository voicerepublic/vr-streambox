module Streambox

  class Reporter

    def serial
      return @serial unless @serial.nil?
      md = File.read('/proc/cpuinfo').match(/Serial\s*:\s*(.*)/)
      @serial = md.nil? ? serial_fallback : md[1]
    end

    def subtype
      @subtype ||= File.exist?('/home/pi/subtype') ?
                     File.read('/home/pi/subtype') : 'dev'
    end

    # TODO make it a nice hash
    def report
      {
        uptime: uptime,
        usb: usb_devices,
        temperature: temperature,
        memory: memory
      }
    end

    private

    def serial_fallback
      [%x[ whoami ].chomp, %x[ hostname ].chomp] * '@'
    end

    def memory
      _, total, used, free, _ = %x[ free | grep Mem ].split(/\s+/)
      { total: total, used: used, free: free }
    end

    def temperature
      return 0 if subtype == 'dev'
      %x[ vcgencmd measure_temp ].match(/=(.+)'/)[1].to_f
    end

    # TODO split up details
    def uptime
      %x[ uptime ].chomp.strip
    end

    def usb_devices
      return [] if subtype == 'dev'
      current = %x[ lsusb ].split("\n").sort
      current - known_usb_devices
    end

    def known_usb_devices
      @known ||= File.read(lsusb_path).split("\n").sort
    end

    def lsusb_path
      @lsusb_path ||= File.expand_path(File.join(%w(.. .. .. lsusb.txt)), __FILE__)
    end

  end
end
