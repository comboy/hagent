require 'serialport'

class Hagent
  class ArdAlarm

    L_FAIL = 5

    C_PING = 46 # .

    # TODO abstract away custom road only sensor/switch
    class Led
      def initialize(number)
        @number = number
        @on_change_blocks = []
      end

      def read
        @value
      end

      def mode=(mode)
        raise "that's an input" unless mode == :input
        true
      end

      def on_change(&block)
        @on_change_blocks << block
      end

      def value=(value)
        prev_value = @value
        @value = value
        @on_change_blocks.each {|b| b.call } if prev_value != value
      end

      def value
        @value
      end
    end

    def initialize(port='/dev/ttyUSB0', baud=9600)
      @sp = SerialPort.new port, baud
      @sp.read_timeout = 0

      @last_ping = Time.now
      @ping_received = false

      @keep_alive_thread = Catcher.thread('keep alive') do
        loop do
          Catcher.block "alarm keep alive" do
            if (Time.now - @last_ping) > 5
              # FIXME some better reporting
      #        raise "alarm did not respond to ping" if !@ping_received
      #        @ping_received = false
      #        @sp.write C_PING.chr
      #        @last_ping = Time.now
            end
          end
          sleep 1
        end
      end

      @listen_thread = Catcher.thread('listen') do
        loop do
          byte = @sp.getbyte
          char = byte.chr

          if char == '+' || char == '-'
            input = @sp.getbyte - 'a'.ord
            value = (char == '+')
            puts "ALARM #{input} is #{value}"
          else
            puts "?? => #{char}"
          end
        end
      end
    end

    def send_sequence(str)
      str.each_byte do |x|
        @sp.write x.chr # mutex? check if serialport handles multithreading
      end
    end

    def key_sequence(str)
      str.each_byte do |x|
        @sp.write x.chr # mutex? check if serialport handles multithreading
        sleep 0.1
        @sp.write '^' # mutex? check if serialport handles multithreading
        sleep 0.3
      end
    end

    def led_fail
      @led_fail ||= Led.new
    end

  end
end

