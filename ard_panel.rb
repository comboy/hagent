require 'serialport'

class Hagent
  class ArdPanel
    C_PING   = 46 # .
    C_LIGHT  = 90
    C_HELLO  = 63 # ?

    R_ACK      = 46  # .
    R_LIGHT    = 90
    R_HELLO    = 63  # ?
    R_ERR      = 33
    R_OK       = 107 # k
    R_ROT_UP   = 43  # +
    R_ROT_DOWN = 45  # -
    R_PCF      = 80  # P

    class Lcd < Hagent::Output::Lcd::Engine::Base
      def initialize(ard)
        @ard = ard
      end

      def print_line(num, text)
        text = text[0..15]
        text = text.ljust(16)
        @ard.send_data("#{num+1}#{text}")
      end

      def set_led(value)
        @ard.send_data(value ? 'B' : 'b')
      end
    end

    class Rotenc < Hagent::Input::Rotenc::Engine::Base
      def initialize(ard)
        super
        @ard = ard
        Catcher.thread("ardpanel rotenc queue") do
          loop do
            event = @ard.rotenc_events.pop
            @event_queue.push event
          end
        end
      end
    end

    attr_accessor :rotenc
    attr_accessor :lcd
    attr_accessor :pcf

    attr_accessor :rotenc_events

    def initialize(port='/dev/ttyAMA0', baud=57600)
      @sp = SerialPort.new port, baud
      @sp.read_timeout = 0

      @rotenc_events = Queue.new
      @rotenc = Rotenc.new self
      @lcd = Lcd.new self
      @pcf = Hagent::PCF8574.new stub: true

      @write_mutex = Mutex.new


      @keep_alive_thread = Catcher.thread('keep alive') do
        loop do
          send_data C_PING.chr
          sleep 5
        end
      end

      # TODO hceck alive ie monitor last_ack

      # we could discover single switch state here, but oh well, maybe one day, not very important
      send_data C_HELLO.chr


      @listen_thread = Catcher.thread('listen') do
        loop do
          byte = @sp.getbyte
          @last_ack = Time.now if byte == R_ACK

          if byte == C_HELLO
          end

          @rotenc_events.push :up   if byte == R_ROT_UP
          @rotenc_events.push :down if byte == R_ROT_DOWN

          if byte == R_PCF
            state = @sp.readline.to_i
            puts "PCF state: #{state}"
            @pcf.force_state(state)
          end

        end
      end
    end

    def tone(freq=0, delay=0)
      if freq == 0
        send_data 'T'
      else
        send_data "t#{freq} #{delay} "
      end
    end

    def light(num, value)
      raise "incorrect value" if value > 255 || value < 0 
      raise "incorrect light num" unless [1,2,3].include?(num)
      send_data "L#{num}#{value} "
    end

    def send_data(data)
      @write_mutex.synchronize do
        @sp.write data
      end
    end

  end
end

