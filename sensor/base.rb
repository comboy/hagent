class Hagent
  module Sensor
    class Base

      def initialize(opts = {})
        @opts = opts

        # Avoid oscilating values
        @opts[:smoothing] ||= true

        @prev_last_read = nil
        @last_read = nil

        @on_change_blocks = []
        @opts[:read_interval] ||= 2

        Catcher.thread "#{name} reads" do
          loop do
            value = read_sensor
            if @last_read != value
              if !@opts[:smoothing] || (value != @prev_last_read)
                # make last_read assignment in case on change blocks want that value
                @prev_last_read = @last_read
                @last_read = value
                @on_change_blocks.each {|b| b.call }
              end
            end
            sleep @opts[:read_interval]
          end
        end
      end

      def name
        "#{self.class.to_s}#{@opts[:name] ? "::#{opts[:name]}" : ""}"
      end

      def on_change(&block)
        @on_change_blocks << block
      end

      def read
        @last_read || read_sensor
      end

    end
  end
end

