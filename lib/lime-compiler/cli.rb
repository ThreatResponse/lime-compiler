require 'optparse'

module LimeCompiler
  class Cli

    def initialize
      @opts = {}
    end

    def options
      if @opts.empty?
        verbose = false
        gpgsign = false
        clobber = false

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

        parser.on("--clobber", "Overwrite existing files in the module output directory") do |v|
          @opts[:clobber] = v
        end

        parser.on("--gpg-sign", "Sign compiled modules") do |v|
          @opts[:gpgsign] = v
        end

        parser.on("--gpg-id identity", "GPG id for module signing") do |v|
          @opts[:gpgid] = v
        end

        parser.on("--[no-]verbose", "Run verbosely") do |v|
          @opts[:verbose] = v
        end

        begin
          parser.parse!
        rescue Exception => e
          puts e.message
          puts parser
          exit(1)
        end

        if @opts[:verbose].nil?
          @opts[:verbose] = verbose
        end

        if @opts[:clobber].nil?
          @opts[:clobber] = clobber
        end

        if @opts[:gpgsig].nil?
          @opts[:gpgsig] = gpgsign
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
