require 'sensor/base'

class Hagent
  module Sensor
    class DS18B20 < Base

      def initialize(opts = {})
        opts[:read_interval] ||= 1
        @addr = opts[:addr]
        super
      end

      protected
 
      def read_sensor
        lines = File.read("/sys/bus/w1/devices/#{@addr}/w1_slave").split("\n")
        return nil unless lines[0].match /YES$/
        lines[1].match(/t=(\d+)/)[1].to_i / 1_000.0
      end
    end
  end
end
