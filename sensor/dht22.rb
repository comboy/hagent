require 'sensor/base'

class Hagent
  module Sensor
    class DHT22 < Base
      def initialize(opts = {})
        @pin = opts[:pin]
        opts[:read_interval] ||= 20
        super
      end

      protected
 
      def read_sensor
      #  return nil # FIXME
        # FIXME proper path
        response = `python vendor/AdafruitDHT.py 22 #{@pin}`
        response.split('Humidity=').last[0..-2].to_f
      end
    end
  end
end
