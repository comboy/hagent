class Hagent
  class PCF8574
    class Pin
      def initialize(pcf, number)
        @pcf = pcf
        @number = number
        @mode = :output
        @value = nil
      end

      def on_change(&block)
        @pcf.on_change do |prev_state|
          if (value != value(prev_state))
            block.call
          end
        end
      end

      def output?
        @mode == :output
      end

      def input?
        @mode == :input
      end

      def mode=(mode)
        @mode = mode
      end

      def value(state = nil)
        (state || @pcf.state) & 1 << @number > 0
      end

      def read
        !value
      end

      def set(value)
        @pcf.pin_set(@number, value)
      end
    end

    attr_accessor :state

    def initialize(opts = {})
      @addr = opts[:addr] || '0x20'
      @i2cbus = opts[:i2cbus] || 1
      @int = opts[:int] || nil
      @pins = Array.new(8) {|i| Pin.new self, i }
      @state = read_state
      puts "state: #{@state}"
      @on_change_blocks = []
      if @int
        Thread.new do
          begin
            loop do
              `gpio wfi #{@int} both`
              prev_state = @state
              sleep 0.01
              @state = read_state
              Thread.new do
                @on_change_blocks.each {|b| b.call(prev_state) }
              end
            end
          rescue Exception => e
            puts "SHIT #{e}"
          end
        end
      end
    end

    def pin(number)
      @pins[number]
    end

    def read_state
      raw = ex "i2cget -y #{@i2cbus} #{@addr}"
      state = raw.split('x').last.to_i(16)
      puts "read state: #{state.to_s(2)}"
      state
    end

    def on_change(&block)
      @on_change_blocks << block
    end

    def pin_set(pin, value)
      # let's default to negation for PCF since output on will always be low
      value = !value
      new_state = @state
      new_state = @state ^ 1 << pin if ((@state & 1 << pin) > 0) != value
      puts "oldstate: #{@state}, newstate: #{new_state}"
      write_state(new_state)
    end

    def pin_state(pin)
      zo = @state.to_s(2)
      zo[7-pin].to_i
    end

    def write_state(new_state)
      inputs_mask = 0
      @pins.each_with_index do |pin, i|
        inputs_mask = inputs_mask | 1 << i if pin.input?
      end
      # We use inputs_mask to make sure input pins are always set high
      # (even if they are reading low at the moment)
      @state = new_state
      ex "i2cset -y #{@i2cbus} #{@addr} 0x#{(@state | inputs_mask).to_s(16)}"
    end

    def ex(cmd)
      #puts "ex: #{cmd}"
      `#{cmd}`
    end
  end
end
