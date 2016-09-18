require 'optparse'

module LimeCompiler
  class Cli

    def initialize
      @opts = {}
    end

    def options
      if @opts.empty?
        verbose = false

        parser = OptionParser.new
        parser.banner = "Usage: lime-compiler [options]"

        parser.on("-h", "--help", "Show this help message") do ||
          puts parser
          exit(0)
        end

        parser.on("-v", "--version", "Print gem version") do ||
          puts LimeCompiler::VERSION
          exit(0)
        end

        parser.on("-c", "--config config.yml", "[Required] path to config file") do |v|
          @opts[:config] = v
        end

        parser.on("-m", "--moduledir modules/", "[Required] module output directory") do |v|
          @opts[:module_dir] = v
        end

        parser.on("-a", "--archive archive/", "[Required] archive output directory") do |v|
          @opts[:archive_dir] = v
        end

        parser.on("--[no-]verbose", "Run verbosely") do |v|
          @opts[:verbose] = v
        end

        parser.parse!

        if @opts[:verbose].nil?
          @opts[:verbose] = verbose
        end

        if @opts[:config].nil? || @opts[:module_dir].nil? || @opts[:archive_dir].nil?
          puts parser
          exit(1)
        end

      end

      @opts

    end

    def validate opts
      raise "invalid archive directory path" unless File.directory?(opts[:archive_dir])
      raise "invalid module directory path" unless File.directory?(opts[:module_dir])
      raise "invalid config file path" unless File.exist?(opts[:config])
    end

  end
end
