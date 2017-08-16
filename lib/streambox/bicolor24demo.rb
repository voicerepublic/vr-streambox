class Bicolor24Demo

  SEGMENTS = 24
  UNIT = 1.0 / SEGMENTS

  def run
    Thread.new do
      @high = 0
      @value = 0.5
      loop do
        begin
          @value += (rand - 0.5) * UNIT * 7
          @value = 0 if @value < 0
          @value = 1 if @value > 1

          @high = @value if @high < @value
          @high -= UNIT if @high > @value
          @high = 0 if @high < 0
          @high = 1 if @high > 1

          @segs = (@value * SEGMENTS).to_i
          @hiseg = (@high * SEGMENTS).to_i

          if block_given?
            yield @segs, @hiseg
          else
            str = "|" * @segs + ' ' * (SEGMENTS - @segs)
            str[@hiseg] = 'I'
            puts str
          end

          sleep 0.05
        rescue
          puts @value
          puts @high
        end
      end
    end
  end

end

Bicolor24Demo.new.run.join if $0 == __FILE__
