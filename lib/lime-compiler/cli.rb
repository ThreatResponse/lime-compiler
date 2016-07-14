require 'optparse'

module LimeCompiler
  class Cli

    def initialize
      @opts = {}
    end

    def options
      if @opts.empty?
        parser = OptionParser.new
        # TODO: update banner
        parser.banner = "Usage: lime-compiler [options]"

        parser.on("-h", "--help", "Show this help message") do ||
          puts parser
          exit(0)
        end

        parser.on("-c", "--config config.yml", "[Required] path to config file") do |v|
          @opts[:config] = v
        end

        parser.parse!

        if @opts[:config].nil?
          puts parser
          exit(1)
        end

      end

      @opts

    end

  end
end
