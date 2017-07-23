require 'logger'
require 'fileutils'
require 'yaml'
require 'aws-sdk'
require_relative 'cli'
require_relative 'compile_target'
require_relative 'gpg'

module LimeCompiler
  class Application
    def initialize
      @cli = Cli.new
      @config = configure(@cli.options)
    end

    def configure(options)
      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler'
      end

      @logger.formatter = proc do |sev, dt, name, msg|
        "#{dt.strftime('%Y-%m-%dT%H:%M:%S%:z')} - #{name} - #{sev} - #{msg}\n"
      end

      @logger.level = if options[:verbose]
                        Logger::DEBUG
                      else
                        Logger::INFO
                      end

      config = validate options

      if config[:aws_profile]
        Aws.config.update(
          credentials: Aws::SharedCredentials.new(
            profile_name: config[:aws_profile]
          )
        )
      end

      Aws.config.update(region: config[:aws_region]) if config[:region]

      config
    end

    def validate(options)
      begin
        @logger.debug "validating options #{options}"
        @cli.validate options
        options[:config] = YAML.safe_load(File.read(options[:config_path]))
        config = symbolize options
      rescue Exception => e
        @logger.fatal e.message
        @logger.debug e.backtrace.inspect
        exit(1)
      end

      config
    end

    def run
      existing_modules = repo.modules
      @logger.debug "existing modules found: #{existing_modules}"

      pull_images

      if @config[:repo_opts][:gpg_sign]
        existing_modules.each do |mod|
          sig_path = gpg_client.sign(
            mod, overwrite: @config[:repo_opts][:sign_all]
          )
          repo.generate_metadata mod, sig_path
        end
      else
        sig_path = nil
        existing_modules.each do |mod|
          repo.generate_metadata mod, sig_path
        end
      end

      errors = []
      @config[:config][:images].each do |name, image|
        container_name = "lime_build_#{image[:image]}_#{image[:tag]}"
        distro_name = image[:distribution]
        distro = @config[:config][:distributions][distro_name.to_sym]

        @logger.info(
          "creating container #{container_name} from #{image[:image]}:#{image[:tag]}"
        )
        container = docker_client.container(container_name,
                                            image[:image],
                                            image[:tag],
                                            start: true,
                                            reuse: true)

        container_opts = { name: container_name, archive_name: name,
                           distro: distro, container: container,
                           existing_modules: existing_modules }

        compile_lime container, container_opts, errors
      end

      if errors.empty?
        generate_repodata
      else
        @logger.fatal(
          "refusing to generate repo metadata due to the following errors #{errors}"
        )
      end

      docker_client.cleanup_containers(delete: false)
    end

    def pull_images
      @config[:config][:images].each do |_, image|
        @logger.info "pulling latest for #{image[:image]}:#{image[:tag]}"
        docker_client.pull(image[:image], image[:tag])
      end
    end

    def compile_lime(container, container_opts, errors)
      target = CompileTarget.new(container_opts.merge!(@config[:build_opts]))

      begin
        target.pre_actions
        target.update_sources
        target.install_dependencies
        target.clone_lime
        target.create_directories
        target.compile_lime
        modules = target.write_archive
        @logger.debug "exported kernel modules: #{modules}"

        if @config[:repo_opts][:gpg_sign]
          modules.each do |mod|
            sig_path = gpg_client.sign(mod, overwrite: @config[:repo_opts][:sign_all])
            repo.generate_metadata mod, sig_path
          end
        else
          sig_path = nil
          modules.each do |mod|
            repo.generate_metadata mod, sig_path
          end
        end
      rescue Exception => e
        errors.append(e)
        @logger.fatal e.message
        @logger.debug e.backtrace.inspect
      end
      docker_client.cleanup_container(container, delete: false)

      errors
    end

    def generate_repodata
      repomd_path = repo.generate_repodata @config[:repo_opts][:module_dir]
      @logger.debug "generated repodata #{repomd_path}"
      return unless @config[:repo_opts][:gpg_sign]
      repomd_sig_path = gpg_client.sign(repomd_path, overwrite: true)
      @logger.debug "signed repo metadata #{repomd_sig_path}"
      FileUtils.rm_r @config[:repo_opts][:gpg_home] if @config[:repo_opts][:rm_gpg_home]
    end

    def docker_client
      unless @docker_client
        @docker_client = LimeCompiler::DockerClient.new(@config[:config][:docker])
      end

      @docker_client
    end

    def repo
      @repo = Repo.new(@config[:repo_opts]) unless @repo

      @repo
    end

    def gpg_client
      if !@gpg && @config[:repo_opts][:gpg_sign]
        @gpg = GPG.new(@config[:gpg_opts])
        @gpg.import_key if import_key_required_opts @config
      end

      @gpg
    end

    def symbolize(config)
      Hash[config.map do |k, v|
        if v.is_a?(Hash)
          [k.to_sym, symbolize(v)]
        else
          [k.to_sym, v]
        end
      end]
    end

    def import_key_required_opts(opts)
      gpg_ok = !(opts[:gpg_opts][:gpg_id].nil? && opts[:gpg_opts][:aes_export].nil? && opts[:gpg_opts][:gpg_export].nil?)
      repo_ok = !opts[:repo_opts][:gpg_sign].nil?

      gpg_ok && repo_ok
    end

    def self.log_level
      @logger.level
    end
  end
end
