module Streambox
  class Player < Struct.new(:url)

    def play!
      @pid = spawn("mplayer #{url}")
    end

    def stop!
      Process.kill(@pid)
    end

  end
end
