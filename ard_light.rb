require 'serialport'

class Hagent
  class ArdLight
    C_PING  = 46
    C_LIGHT = 90
    C_HELLO = 63

    R_ACK   = 46
    R_LIGHT = 90
    R_HELLO = 63
    R_ERR   = 33

    class PhotoResistor < Hagent::Sensor::Base
      def initialize(opts = {})
        @ard = opts.delete :ard
        @opts = opts
        @opts[:read_interval] ||= 15
        super
      end

      def read_sensor
        @ard.photo_read
      end
    end

    class Switch
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
        @value = value
        @on_change_blocks.each {|b| b.call }
      end

      def value
        @value
      end
    end

    class Light
      def initialize(number, ard)
        @number = number
        @ard = ard
      end

      def read
        @state
      end

      def state=(state)
        @state = state
      end

      def set(state)
        @state = state
        @ard.set_light(@number, state)
      end
    end

    def initialize(port='/dev/ttyAMA0', baud=9600)
      @sp = SerialPort.new port, baud
      @sp.read_timeout = 0

      @switches = {}
      @lights = {}

      @sw_count = 0
      @keep_alive_thread = Catcher.thread('keep alive') do
        loop do
          @sp.write C_PING.chr
          sleep 5
        end
      end

      @photo_resistor = PhotoResistor.new ard: self
      @photo_q = Queue.new

      # TODO check alive thread?

      # discover @sw_count
      @sp.write C_HELLO.chr


      @listen_thread = Catcher.thread('listen') do
        loop do
          byte = @sp.getbyte
          @last_ack = Time.now if byte == R_ACK

          if byte == C_HELLO
            resp = @sp.gets
            @sw_count = resp.to_i
            puts "found #{@sw_count} switches"
            raise "no defined switches? #{resp}" if @sw_count == 0
          end

          if byte == R_LIGHT
            @photo_read = @sp.gets.to_i
            @photo_q.push @photo_read
          end

          @sw_count.times do |i|
            if byte == 100 + i*4 + 0
              switch(i).value = false
              puts "SW OFF #{i}"
            elsif byte == 100 + i*4 + 1
              switch(i).value = true
              puts "SW ON #{i}"
            elsif byte == 100 + i*4 + 2
              puts "state OFF #{i}"
              light(i).state = false
            elsif byte == 100 + i*4 + 3
              puts "state ON #{i}"
              light(i).state = true
            end
          end

        end
      end
    end

    def switch(num)
      @switches[num] ||= Switch.new num
    end

    def set_light(num, state)
      wha = (100 + num*4 + 2 + (state ? 1 : 0))
      @sp.write wha.chr
    end

    def light(num)
      @lights[num] ||= Light.new num, self
    end

    def photo_resistor
      @photo_resistor
    end

    def photo_read
      @photo_q.clear
      @sp.write C_LIGHT.chr
      @photo_q.pop
    end

  end
end

