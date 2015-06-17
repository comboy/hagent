require 'serialport'

class Hagent
  class ArdAlarm

    R_ON    = 43 # +
    R_OFF   = 45 # -
    R_WAT   = 63 # ?

    L_MALFUNCTION = 5
    L_ARMED       = 4
    L_PIR_DOOR    = 2
    L_PIR_SALON   = 1

    L_OFFSET  = 97

    C_PING    = 46  # .
    C_RELEASE = 94  # ^
    C_VOLTAGE = 118 # v

    # TODO abstract away custom input
    class Input
      def initialize
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

    class VoltageSensor < Hagent::Sensor::Base
      def initialize(opts = {})
        @ard = opts.delete :ard
        @opts = opts
        @opts[:read_interval] ||= 60
        super
      end

      def read_sensor
        @ard.voltage_value
      end
    end

    attr_reader :voltage_value
    attr_reader :voltage


    def initialize(port='/dev/ttyUSB0', baud=9600)
      @sp = SerialPort.new port, baud
      @sp.read_timeout = 0

      @last_ping = Time.now
      @ping_received = true
      @last_voltage = Time.now - 60

      @last_malfunction = Time.now

      @voltage = VoltageSensor.new ard: self

      @keep_alive_thread = Catcher.thread('keep alive') do
        loop do
          Catcher.block "alarm keep alive" do
            if (Time.now - @last_ping) > 10
              # FIXME some better reporting
              if !@ping_received
                responding.value = false
              end
              @ping_received = false
              @sp.write C_PING.chr
              @last_ping = Time.now
            end

            if (Time.now - @last_voltage) > 60
              @sp.write C_VOLTAGE.chr
              @last_voltage = Time.now
              @read_voltage = true
            end

            if malfunction.value && (Time.now - @last_malfunction) > 10
              malfunction.value = false
            end

          end
          sleep 1
        end
      end

      @listen_thread = Catcher.thread('listen') do
        loop do
          byte = @sp.getbyte
          char = byte.chr

          if @read_voltage && byte == C_VOLTAGE
            vstr = ''
            loop do
              byte = @sp.getbyte
              char = byte.chr
              break if byte == R_WAT
              vstr << char
            end
            value = vstr.to_i
            voltage = ((value / 1024.0) * 5) * 3

            @voltage_value = voltage.round(2)
            @read_voltage = false
            next
          end

          if byte == R_ON || byte == R_OFF
            input = @sp.getbyte - L_OFFSET
            value = (byte == R_ON)
            #puts "ALARM #{input} is #{value}"
            case input
            when L_MALFUNCTION
              malfunction.value = true
              @last_malfunction = Time.now
            when L_PIR_DOOR
              pir_door.value = value
            when L_PIR_SALON
              pir_salon.value = value
            when L_ARMED
              armed.value = value
            else
              puts "INP #{input} #{value}"
            end
          elsif byte == C_PING
            @ping_received = true
            responding.value = true
          else
            puts "?? => #{char}"
          end
        end
      end
    end

    def send_sequence(str)
      str.each_byte do |x|
        @sp.write x.chr
      end
    end

    def key_sequence(str)
      str.each_byte do |x|
        @sp.write x.chr
        sleep 0.1
        @sp.write C_RELEASE.chr
        sleep 0.3
      end
    end

    def responding
      @s_responding ||= Input.new
    end

    def malfunction
      @s_malfunction ||= Input.new
    end

    def armed
      @s_armed ||= Input.new
    end

    def pir_door
      @s_pir_door ||= Input.new
    end

    def pir_salon
      @s_pir_salon ||= Input.new
    end

  end
end

