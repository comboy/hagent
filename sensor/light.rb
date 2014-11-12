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
        system("gpio -g mode #{@pin} out")
        system("gpio -g write #{@pin} 0")
        sleep 0.1
        system("gpio -g mode #{@pin} in")
        t0 = Time.now
        loop do
          # so slow, sucks really bad, I don't know why wfi sucks even more
          ret = `gpio -g read #{@pin}`.to_i
          #puts "ret: #{ret}"
          break if ret == 1
        end
        #system("gpio -g wfi #{@pin} both")
        t = Time.now - t0
        ret = (t * 1000.0).to_i
        (1 / ret.to_f * 1000).round(2)
      end
    end
  end
end
