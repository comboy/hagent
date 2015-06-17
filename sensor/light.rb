require 'sensor/base'

class Hagent
  module Sensor
    class Light < Base
      def initialize(opts = {})
        @pin = opts[:pin]
        opts[:read_interval] ||= 200
        super
      end

      protected
 
      def read_sensor
        return 0
        `gpio -g mode #{@pin} out`
        `gpio -g write #{@pin} 0`
        sleep 0.1
        `gpio -g mode #{@pin} in`
        t0 = Time.now
        `gpio -g wfi #@pin both`
        t = Time.now - t0
        ret = (t * 1000.0).to_i
        (1 / ret.to_f * 1000).round(2)
      end
    end
  end
end
