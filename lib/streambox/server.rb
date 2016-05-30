require 'thin'

module Streambox
  class Server

    WEB_HOST = '127.0.0.1'
    WEB_PORT = 8000

    def initialize
      instance = Thin::Server.new(WEB_HOST, WEB_PORT, handler)
      @thread = Thread.new { instance.start }
    end

    def handler
      lambda do |env|
        [200, {}, template]
      end
    end

    def template
      @template ||= File.read(__FILE__).split('__END__').last
    end

  end
end

__END__
<html>
  <body>
    <div id='graph'>hello</div>
    <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.14/d3.min.js"></script>
    <script type='text/javascript'>
      // TODO subscribe
    </script>
  </body>
</html>
