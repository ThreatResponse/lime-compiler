require 'ostruct'
require 'inifile'


module LimeCompiler
  class Configuration

    FLAGS = {
      verbose: :common,
      debug: :common
    }

    CONFIG_LOCATIONS = [
      '.lime-compiler.conf',
      '~/.lime-compiler.conf',
      '/etc/lime-compiler/lime-compiler.conf'
    ]

    CONFIG_SECTIONS = [
      :common, :aws, :docker, :build, :repo, :repo_signing
    ]

    SECTION_KEYS = {
      common: ['verbose', 'debug' ],
      docker: ['url', 'write_timeout', 'read_timeout'],
      aws: ['profile', 'region'],
      build: ['root', 'cleanup', 'rebuild'],
      repo: ['packager', 'platform', 'sign', 'path'],
      repo_signing: [
        'sign_all', 'verify_existing', 'gpg_fingerprint', 'gpg_home',
        'remove_gpg_home', 'aes_key_import_path', 'gpg_key_import_path'
      ]
    }

    def initialize
      @user_config = nil
      @flags = {}
      @conf = defaults

      CONFIG_SECTIONS.each do |section|
        self.class.send(:define_method, section.to_sym) { self.get.send(section) }
      end
    end

    def to_h
      @conf.to_h
    end

    def user_config=(value)
      @user_config = value
      reload!
    end

    def reload!
      #TODO: debug log message -> reloading config
      @conf = defaults
      if @user_config
        begin
          @conf = Configuration.merge(@conf, Configuration.from_ini(@user_config))
        rescue RuntimeError => e
          #TODO: use application logger
          puts "Error merging configurations #{e}"
        end
      end
      apply_flags!
    end

    def set_flag(name, value)
      @flags[name.to_sym] = value
      apply_flags!
    end

    def default? section, key
      @conf[section][key] == self.send("#{section}_opts")[key]
    end

    def self.from_ini path
      if File.file?(File.expand_path(path))
        ini_file = IniFile.load(File.expand_path(path))
      else
        #TODO: replace with proper exception
        raise "No such file or directory - File Not Found - \"#{path}\""
      end

      config = OpenStruct.new
      CONFIG_SECTIONS.each do |section|
        SECTION_KEYS[section].each do |key|
          unless ini_file[section][key].nil?
            if config[section].nil?
              config[section] = OpenStruct.new
            end
            config[section][key.to_sym] = ini_file[section][key]
          end
        end
      end

      config
    end

    def self.merge default, config
      CONFIG_SECTIONS.each do |section|
        default[section] = OpenStruct.new(
          if config[section].nil?
            default[section].to_h
          else
            default[section].to_h.merge(config[section].to_h)
          end
        )
      end

      default
    end

    protected

      def defaults
        default_config = OpenStruct.new({
          common: common_opts,
          docker: docker_opts,
          aws: aws_opts,
          build: build_opts,
          repo: repo_opts,
          repo_signing: repo_signing_opts,
        })

        config = self.config_from_default_location

        if config
          Configuration.merge(default_config, config)
        else
          default_config
        end
      end

      def get
        @conf
      end

      def apply_flags!
        FLAGS.each do |key, section|
          unless @flags[key].nil?
            @conf[section][key] = @flags[key]
          end
        end
      end

      def config_from_default_location
        config = nil
        CONFIG_LOCATIONS.each do |path|
          if File.file?(File.expand_path(path))
            config = Configuration.from_ini(path)
            break
          end
        end

        config
      end

      def common_opts
        OpenStruct.new({
          verbose: false,
          debug: false
        })
      end

      def docker_opts
        OpenStruct.new({
          url: 'unix:///var/run/docker.sock',
          write_timeout: 1800,
          read_timeout: 1800
        })
      end

      def aws_opts
        OpenStruct.new({
          profile: nil,
          region: nil,
        })
      end

      def build_opts
        OpenStruct.new({
          root: '/tmp/lime-build',
          cleanup: false,
          rebuild: false
        })
      end

      def repo_opts
        OpenStruct.new({
          packager: nil,
          platform: nil,
          sign: false,
          path: nil,
        })
      end

      def repo_signing_opts
        OpenStruct.new({
          sign_all: false,
          verify_existing: true,
          gpg_fingerprint: nil,
          gpg_home: "~/.gnupg",
          remove_gpg_home: nil,
          aes_key_import_path: nil,
          gpg_key_import_path: nil,
        })
      end

  end
end
