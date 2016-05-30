module Streambox
  class Player < Struct.new(:url)

    def play!
      @pid = spawn("mplayer -cache 100 #{url} ")
    end

    def stop!
      Process.kill('INT', @pid)
    end

  end
end
