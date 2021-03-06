require 'optparse'

module LimeCompiler
  class Cli

    DEFAULT_OPTIONS = { config: nil,
                        config_path: nil,
                        verbose: false,
                        repo_opts: { module_dir: nil,
                                     archive_dir: nil,
                                     packager: nil,
                                     platform: nil,
                                     gpg_sign: false,
                                     sign_all: false,
                                     gpg_no_verify: false,
                                     gpg_home: "~/.gnupg",
                                     rm_gpg_home: false,
                                     gpg_id: nil},
                        build_opts: { build_all: false,
                                      module_dir: nil,
                                      archive_dir: nil },
                        gpg_opts: { gpg_home: "~/.gnupg",
                                    gpg_id: nil,
                                    aes_export: nil,
                                    gpg_export: nil,
                                    s3_region: nil },
                        kms_opts: { kms_region: nil } }

    REQUIRED_KEYS = [:config_path]
    REQUIRED_SUBKEYS = { build_opts: [:module_dir, :archive_dir] }

    def initialize
      @opts = {}
    end

    def options
      if @opts.empty?
        @opts = DEFAULT_OPTIONS
        exit_with_error = false
        exit_without_error = false

        parser = OptionParser.new
        parser.banner = "Usage: lime-compiler [options]"

        parser.on("-h", "--help", "Show this help message") do ||
          puts parser
          exit_without_error = true
        end

        parser.on("-v", "--version", "Print gem version") do ||
          unless exit_without_error
            puts LimeCompiler::VERSION
            exit_without_error = true
          end
        end

        parser.on("-c", "--config config.yml", "[Required] path to config file") do |v|
          @opts[:config_path] = v
        end

        parser.on("-m", "--moduledir modules/", "[Required] module output directory") do |v|
          @opts[:repo_opts][:module_dir] = v
          @opts[:build_opts][:module_dir] = v
        end

        parser.on("-a", "--archive archive/", "[Required] archive output directory") do |v|
          @opts[:repo_opts][:archive_dir] = v
          @opts[:build_opts][:archive_dir] = v
        end

        parser.on("--build-all", "Rebuild existing lime modules in the build root") do |v|
          @opts[:build_opts][:build_all] = v
        end

        parser.on("--gpg-sign", "Sign compiled modules") do |v|
          @opts[:repo_opts][:gpg_sign] = v
        end

        parser.on("--sign-all", "Regenerate signatures for existing modules in build root") do |v|
          @opts[:repo_opts][:sign_all] = v
        end

        parser.on("--gpg-id identity", "GPG id for module signing") do |v|
          @opts[:repo_opts][:gpg_id] = v
          @opts[:gpg_opts][:gpg_id] = v
        end

        parser.on("--gpg-no-verify", "Bypass gpg signature checks") do |v|
          @opts[:repo_opts][:gpg_no_verify] = v
        end

        parser.on("--gpg-home path/to/gpghome", "Custom gpg home directory") do |v|
          @opts[:gpg_opts][:gpg_home] = v
          @opts[:repo_opts][:gpg_home] = v
        end

        parser.on("--rm-gpg-home", "Custom gpg home directory") do |v|
          @opts[:repo_opts][:rm_gpg_home] = v
        end

        parser.on("--kms-region region", "AWS region for KMS client instantiation") do |v|
          @opts[:kms_opts][:kms_region] = v
        end

        parser.on("--s3-region region", "AWS region for S3 client instantiation") do |v|
          @opts[:gpg_opts][:s3_region] = v
        end

        parser.on("--aes-key-export export.aes", "Path to aes key export created with gpg-setup") do |v|
          @opts[:gpg_opts][:aes_export] = v
        end

        parser.on("--gpg-key-export export.aes", "Path to encrypted gpg key created with gpg-setup") do |v|
          @opts[:gpg_opts][:gpg_export] = v
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

        validation_errors = []
        unless exit_without_error
          REQUIRED_KEYS.each do |key|
            if @opts[key].nil?
              validation_errors << "config missing required key: #{key}"
              exit_with_error = true
            end
          end

          REQUIRED_SUBKEYS.each do |key, subkeys|
            subkeys.each do |subkey|
              if @opts[key][subkey].nil?
                validation_errors << "config missing required key: #{subkey}"
                exit_with_error = true
              end
            end
          end
        end

        if exit_with_error
          validation_errors.each do |v|
            puts v
          end
          puts parser
        end

      end

      if exit_with_error
        exit(1)
      elsif exit_without_error
        exit(0)
      end

      @opts
    end

    def validate opts
      raise "invalid archive directory path" unless File.directory?(opts[:repo_opts][:archive_dir])
      raise "invalid module directory path" unless File.directory?(opts[:repo_opts][:module_dir])
      raise "invalid config file path" unless File.exist?(opts[:config_path])
    end

  end
end
