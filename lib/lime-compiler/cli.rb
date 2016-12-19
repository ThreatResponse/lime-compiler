require 'optparse'

module LimeCompiler
  class Cli

    def initialize
      @opts = {}
    end

    def options
      if @opts.empty?
        verbose = false
        build_all = false
        sign_all = false
        gpgsign = false
        gpgnoverify = false
        quit = false
        error = false

        parser = OptionParser.new
        parser.banner = "Usage: lime-compiler [options]"

        parser.on("-h", "--help", "Show this help message") do ||
          puts parser
          quit = true
        end

        parser.on("-v", "--version", "Print gem version") do ||
          unless quit
            puts LimeCompiler::VERSION
            quit = true
          end
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

        parser.on("--build-all", "Rebuild existing lime modules in the build root") do |v|
          @opts[:build_all] = v
        end

        parser.on("--sign-all", "Regenerate signatures for existing lime modules in the build root") do |v|
          @opts[:sign_all] = v
        end

        parser.on("--gpg-sign", "Sign compiled modules") do |v|
          @opts[:gpgsign] = v
        end

        parser.on("--gpg-id identity", "GPG id for module signing") do |v|
          @opts[:gpgid] = v
        end

        parser.on("--gpg-no-verify", "Bypass gpg signature checks") do |v|
          @opts[:gpgnoverify] = v
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

        if @opts[:build_all].nil?
          @opts[:build_all] = build_all
        end

        if @opts[:sign_all].nil?
          @opts[:sign_all] = build_all
        end

        if @opts[:gpgsign].nil?
          @opts[:gpgsign] = gpgsign
        end

        if @opts[:gpgnoverify].nil?
          @opts[:gpgnoverify] = gpgnoverify
        end

        if @opts[:config].nil? || @opts[:module_dir].nil? || @opts[:archive_dir].nil?
          unless quit
            puts parser
            quit = true
          end
        end

      end

      if quit == true
        exit(1)
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
