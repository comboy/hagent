class Hagent
  class RPI
    class Pin # GPIO PIN
      def initialize(number, opts={})
        # TODO mode out
        @mode = :input
        @number = number
        @on_change_blocks = []

        `gpio -g mode #@number in`
        Catcher.thread "rpi gpio in listen" do
          loop do
            `gpio -g wfi #@number both`
            @on_change_blocks.each do |block|
              block.call
            end
          end
        end
      end

      def on_change(&block)
        @on_change_blocks << block
      end

      def mode=(mode)
        @mode = mode
      end

      def read
        val = `gpio -g read #@number`
        val.to_i == 1
      end
    end # Pin

    def initialize
      @pins = {}
    end

    def input(number)
      @pins[number] ||= Pin.new number, mode: :input
    end
  end
end
