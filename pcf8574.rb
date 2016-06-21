class Hagent
  class PCF8574
    class Pin
      def initialize(pcf, number)
        @pcf = pcf
        @number = number
        @mode = :output
        @value = read_value
      end

      def on_change(&block)
        @pcf.on_change do |prev_state, new_state|
          new_value = read_value(new_state)
          if @value != new_value
            @value = new_value
            #puts "   pin #{@number} #{value}"
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

      def value
        @value.nil? ? read_value : @value
      end

      def read_value(state = nil)
        #puts "PCF  STATE: #{@pcf.state.inspect}"
        (state || @pcf.state) & 1 << @number > 0
      end

      def read
        !read_value
      end

      def set(value)
        @pcf.pin_set(@number, value)
      end
    end

    # opts
    #  addr
    #  i2cbus
    #  stub - used when we only want to have same API for PCF that is actually on arduino
    #         arduino pushes state using #force_state (currently inputs only)
    def initialize(opts = {})
      @addr = opts[:addr] || '0x20'
      @i2cbus = opts[:i2cbus] || 1
      @int = opts[:int] || nil
      @stub = opts[:stub]
      @state = read_state
      @pins = Array.new(8) {|i| Pin.new self, i }
      @rsm = Mutex.new
      @on_change_blocks = []
      @q_check_state = Queue.new

      return if @stub

      # FIXME event can be missed between firing these
      # probably could be fixed by doing read after setting up a hook
      if @int
        system("gpio -g mode #{@int} in")
        Catcher.thread("check state") do
          loop do
            @q_check_state.pop
            sleep 0.3 # let gpio wfi command start
            puts "double check"
            prev_state = nil
            decide = nil
            new_state = nil
            @rsm.synchronize do
              prev_state = @state
              puts "GO prev_state #{prev_state}"
              @state = read_state
              new_state = @state
              puts "GO new state  #{@state}"
              decide = (@state != prev_state)
            end
            if decide #@state != prev_state # in case many PCFs are connected to single interrupt
              Catcher.thread "pcf on change blocks" do
                #puts "##{@number} change!: #{prev_state} -> #{new_state} GOT ONE ====="
                @on_change_blocks.each {|b| b.call(prev_state,new_state) }
              end
            end
          end
        end

        Catcher.thread("pin listen") do
          begin
            loop do
              @q_check_state.push true
              `gpio -g wfi #{@int} both`
              prev_state = nil
              decide = nil
              new_state = nil
              @rsm.synchronize do
                prev_state = @state
                puts "prev_state #{prev_state}"
                #sleep 0.01
                @state = read_state
                new_state = @state
                puts "new state  #{@state}"
                decide = (@state != prev_state)
              end
              if decide #@state != prev_state # in case many PCFs are connected to single interrupt
                Catcher.thread "pcf on change blocks" do
                  puts "##{@number} change!: #{prev_state} -> #{new_state}"
                  @on_change_blocks.each {|b| b.call(prev_state, new_state) }
                end
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

    def state
      @int ? @state : read_state
    end

    def read_state
      return @state || 255 if @stub
      #@rsm.synchronize do
        raw = ex "i2cget -y #{@i2cbus} #{@addr}"
        state = raw.split('x').last.to_i(16)
        #puts "read state: #{state.to_s(2)}"
        state
      #end
    end

    def on_change(&block)
      @on_change_blocks << block
    end

    def pin_set(pin, value)
      # let's default to negation for PCF since output on will always be low
      value = !value
      new_state = @state
      new_state = @state ^ 1 << pin if ((@state & 1 << pin) > 0) != value
      write_state(new_state)
    end

    def pin_state(pin)
      zo = @state.to_s(2)
      zo[7-pin].to_i
    end

    def force_state(new_state)
      @rsm.synchronize do
        prev_state = @state
        @state = new_state
        Catcher.thread "pcf on change blocks" do
          #puts "##{@number} change!: #{prev_state} -> #{new_state}"
          @on_change_blocks.each {|b| b.call(prev_state, new_state) }
        end
      end
    end

    # Writes output to PCF
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
