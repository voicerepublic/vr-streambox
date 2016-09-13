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

    def version
      @version ||= File.exist?('VERSION') ?
                     File.read('VERSION').to_i : 0
    end

    def private_ip_address
      `hostname -I | cut -d ' ' -f 1`.chomp
    end

    def mac_address_ethernet
      File.read('/sys/class/net/eth0/address').chomp
    end

    def mac_address_wifi
      File.read('/sys/class/net/wlan0/address').chomp
    end

    # TODO make it a nice hash
    def report
      {
        uptime: uptime,
        usb: usb_devices,
        temperature: temperature,
        memory: memory,
        disk: disk_free,
        devices: devices
      }
    end

    private

    def devices
      key = nil
      %x[arecord -L].split("\n").inject(Hash.new { |h, k| h[k] = [] }) do |r, l|
        l.match(/^\s+/) ? r[key].push(l.strip) : key=l
        r
      end
    end

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
      current = %x[ lsusb ].split("\n").map { |e| e.strip }.sort
      current - known_usb_devices
    end

    def known_usb_devices
      @known ||= File.read(lsusb_path).split("\n").sort
    end

    def lsusb_path
      @lsusb_path ||= File.expand_path(File.join(%w(.. .. .. lsusb), subtype), __FILE__)
    end

    def disk_free
      df_cmd = 'df / | tail -1'
      _, size, used, avail, pcent, _ = %x[#{df_cmd}].chomp.split(/\s+/)
      { used: used.to_i,
        avail: avail.to_i,
        total: size.to_i,
        pcent: pcent } # 1K-blocks
    end

    # sudo iwlist wlan0 scan

  end
end
