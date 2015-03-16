require 'rf24'
class Hagent
  class ArdVent
    C_TEMP_OUT = 10
    C_HUM      = 11
    C_TEMP_DHT = 12

    C_SHUTTER_ON  = 20
    C_SHUTTER_OFF = 21
    C_VENT_ON     = 22
    C_VENT_OFF    = 23

    R_ACK = 1337

    class Sensor < Hagent::Sensor::Base
      def initialize(opts ={})
        @rf = opts.delete :rf
        @command = opts.delete :command
        opts[:read_interval] ||= 30
        super
      end

      def read_sensor
        resp = @rf.send @command
        return nil unless resp
        resp.to_i / 100.0
      end
    end # Temp

    class Output
      def initialize(opts = {})
        @rf = opts.delete :rf
        @commands = opts.delete :commands
      end

      def set(state)
        resp = @rf.send @commands[state ? 0 : 1]
        # TODO make hagent expect true if set successful
        (resp.to_i == 1337)
      end
    end

    def initialize
      @rf = RF24.new
    end

    def temp_out
      @temp_out ||= Sensor.new rf: @rf, command: C_TEMP_OUT
    end

    def temp_dht
      @temp_dht ||= Sensor.new rf: @rf, command: C_TEMP_DHT
    end

    def hum
      @hum ||= Sensor.new rf: @rf, command: C_HUM
    end

    def shutter
      @shutter ||= Output.new rf: @rf, commands: [C_SHUTTER_ON, C_SHUTTER_OFF]
    end

    def vent
      @vent ||= Output.new rf: @rf, commands: [C_VENT_ON, C_VENT_OFF]
    end
  end
end
