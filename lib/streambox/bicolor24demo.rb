module Bicolor24Demo

  extend self

  SEGMENTS = 24
  UNIT = 1.0 / SEGMENTS

  def run(&bloc)
    puts "a"
    Thread.new do
      @high = 0
      @value = 0.5
      puts "b"
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

          if bloc.nil?
            str = "|" * @segs + ' ' * (SEGMENTS - @segs)
            str[@hiseg] = 'I'
            puts str
          else
            bloc.call @segs, @hiseg
          end

          sleep 0.05
          #rescue => e
          #  puts e
          #  puts @value
          #  puts @high
        end
      end
    end
    puts "c"
  end

end

#Bicolor24Demo.run.join if $0 == __FILE__
