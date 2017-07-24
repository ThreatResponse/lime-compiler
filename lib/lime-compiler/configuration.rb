require 'ostruct'
require 'inifile'

module LimeCompiler
  class Configuration
    FLAGS = {
      verbose: :common,
      debug: :common
    }.freeze

    CONFIG_LOCATIONS = [
      '.lime-compiler.conf',
      '~/.lime-compiler.conf',
      '/etc/lime-compiler/lime-compiler.conf'
    ].freeze

    CONFIG_SECTIONS = %i[common aws docker build repo repo_signing].freeze

    SECTION_KEYS = {
      common: %w[verbose debug],
      docker: %w[url write_timeout read_timeout],
      aws: %w[profile region],
      build: %w[root cleanup rebuild],
      repo: %w[packager platform sign path],
      repo_signing: %w[sign_all verify_existing gpg_fingerprint gpg_home
                       remove_gpg_home aes_key_import_path gpg_key_import_path]
    }.freeze

    def initialize(load_config: true)
      @load_config = load_config
      @user_config = nil
      @flags = {}
      @conf = defaults

      CONFIG_SECTIONS.each do |section|
        self.class.send(:define_method, section.to_sym) { get.send(section) }
      end
    end

    def to_h
      hash = @conf.to_h
      hash.each do |key, value|
        value.instance_of?(OpenStruct) && hash[key] = value.to_h
      end
    end

    def user_config=(value)
      @user_config = value
      reload!
    end

    def reload!
      # TODO: debug log message -> reloading config
      @conf = defaults
      merge!(Configuration.from_ini(@user_config)) if @user_config
      apply_flags!
    end

    def set_flag(name, value)
      @flags[name.to_sym] = value
      apply_flags!
    end

    def default?(section, key)
      @conf[section][key] == send("#{section}_opts")[key]
    end

    def self.from_ini(path)
      return unless File.file?(File.expand_path(path))
      ini_file = IniFile.load(File.expand_path(path))

      config = OpenStruct.new
      CONFIG_SECTIONS.each do |section|
        SECTION_KEYS[section].each do |key|
          unless ini_file[section][key].nil?
            config[section] || config[section] = OpenStruct.new
            config[section][key.to_sym] = ini_file[section][key]
          end
        end
      end

      config
    end

    def merge!(config)
      CONFIG_SECTIONS.each do |section|
        @conf[section] = OpenStruct.new(
          if config.send(section).nil?
            @conf[section].to_h
          else
            @conf[section].to_h.merge(config.send(section).to_h)
          end
        )
      end

      @conf
    end

    protected

    def defaults
      default_config = OpenStruct.new(
        common: common_opts,
        docker: docker_opts,
        aws: aws_opts,
        build: build_opts,
        repo: repo_opts,
        repo_signing: repo_signing_opts
      )

      config = config_from_default_location

      return default_config unless config
      @conf = default_config
      merge! config
    end

    def get
      @conf
    end

    def apply_flags!
      FLAGS.each do |key, section|
        @flags[key].nil? || @conf[section][key] = @flags[key]
      end
    end

    def config_from_default_location
      return unless @load_config
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
      OpenStruct.new(
        verbose: false,
        debug: false
      )
    end

    def docker_opts
      OpenStruct.new(
        url: 'unix:///var/run/docker.sock',
        write_timeout: 1800,
        read_timeout: 1800
      )
    end

    def aws_opts
      OpenStruct.new(
        profile: nil,
        region: nil
      )
    end

    def build_opts
      OpenStruct.new(
        root: '/tmp/lime-build',
        cleanup: false,
        rebuild: false
      )
    end

    def repo_opts
      OpenStruct.new(
        packager: nil,
        platform: nil,
        sign: false,
        path: nil
      )
    end

    def repo_signing_opts
      OpenStruct.new(
        sign_all: false,
        verify_existing: true,
        gpg_fingerprint: nil,
        gpg_home: '~/.gnupg',
        remove_gpg_home: nil,
        aes_key_import_path: nil,
        gpg_key_import_path: nil
      )
    end
  end
end
