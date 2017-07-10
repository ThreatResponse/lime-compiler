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
      @config = self.configure(@cli.options)
    end

    def configure options
      @@logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler'
      end

      @@logger.formatter= proc do |sev, dt, name, msg|
        "#{dt.strftime("%Y-%m-%dT%H:%M:%S%:z")} - #{name} - #{sev} - #{msg}\n"
      end

      if options[:verbose]
        @@logger.level = Logger::DEBUG
      else
        @@logger.level = Logger::INFO
      end

      config = self.validate options

      if config[:aws_profile]
        Aws.config.update({
          credentials: Aws::SharedCredentials.new(profile_name: config[:aws_profile])
        })
      end

      if config[:region]
        Aws.config.update({region: config[:aws_region]})
      end

      config
    end

    def validate options
      begin
        @@logger.debug "validating options #{options}"
        @cli.validate options
        options[:config] = YAML::load_file(options[:config_path])
        config = self.symbolize options
      rescue Exception => e
        @@logger.fatal e.message
        @@logger.debug e.backtrace.inspect
        exit(1)
      end

      config
    end

    def run
      existing_modules = self.repo.modules
      @@logger.debug "existing modules found: #{existing_modules}"

      @config[:config][:images].each do |name, image|
        @@logger.info "pulling latest for #{image[:image]}:#{image[:tag]}"
        self.docker_client.pull(image[:image], image[:tag])
      end


      if @config[:repo_opts][:gpg_sign]
        existing_modules.each do |mod|
          sig_path = self.gpg_client.sign(mod, overwrite: @config[:repo_opts][:sign_all])
          self.repo.generate_metadata mod, sig_path
        end
      else
        sig_path = nil
        existing_modules.each do |mod|
          self.repo.generate_metadata mod, sig_path
        end
      end

      errors = []
      @config[:config][:images].each do |name, image|

        container_name = "lime_build_#{image[:image]}_#{image[:tag]}"
        distro_name = image[:distribution]
        distro = @config[:config][:distributions][distro_name.to_sym]

        @@logger.info "creating container #{container_name} from #{image[:image]}:#{image[:tag]}"
        c = self.docker_client.container(container_name, image[:image], image[:tag],
                               start: true, reuse: true)

        local_opts = { name: container_name, archive_name: name,
                       distro: distro, container: c,
                       existing_modules: existing_modules }

        target = CompileTarget.new(local_opts.merge!(@config[:build_opts]))

        begin
          target.pre_actions
          target.update_sources
          target.install_dependencies
          target.clone_lime
          target.create_directories
          target.compile_lime
          modules = target.write_archive
          @@logger.debug "exported kernel modules: #{modules}"

          if @config[:repo_opts][:gpg_sign]
            modules.each do |mod|
              sig_path = self.gpg_client.sign(mod, overwrite: @config[:repo_opts][:sign_all])
              self.repo.generate_metadata mod, sig_path
            end
          else
            sig_path = nil
            modules.each do |mod|
              self.repo.generate_metadata mod, sig_path
            end
          end

        rescue Exception => e
          errors.append(e)
          @@logger.fatal e.message
          @@logger.debug e.backtrace.inspect
        end
        self.docker_client.cleanup_container(c, delete: false)
      end

      if errors.empty?
        repomd_path = self.repo.generate_repodata @config[:repo_opts][:module_dir]
        @@logger.debug "generated repodata #{repomd_path}"
        if @config[:repo_opts][:gpg_sign]
          repomd_sig_path = self.gpg_client.sign(repomd_path, overwrite: true)
          @@logger.debug "signed repo metadata #{repomd_sig_path}"
          if @config[:repo_opts][:rm_gpg_home]
            FileUtils.rm_r @config[:repo_opts][:gpg_home]
          end
        end
      else
        @@logger.fatal "refusing to generate repo metadata due to the following errors #{errors}"
      end

      self.docker_client.cleanup_containers(delete: false)

    end

    def docker_client
      unless @docker_client
        @docker_client = LimeCompiler::DockerClient.new(@config[:config][:docker])
      end

      @docker_client
    end

    def repo
      unless @repo
        @repo = Repo.new(@config[:repo_opts])
      end

      @repo
    end

    def gpg_client
      if !@gpg and @config[:repo_opts][:gpg_sign]
        @gpg = GPG.new(@config[:gpg_opts])
        if import_key_required_opts @config
          @gpg.import_key
        end
      end

      @gpg
    end

    def symbolize config
      Hash[ config.map do |k,v|
        ret = nil
        if v.is_a?(Hash)
          ret = [k.to_sym, symbolize(v)]
        else
          ret = [k.to_sym, v]
        end
        ret
      end ]
    end

    def import_key_required_opts opts
      gpg_ok = !(opts[:gpg_opts][:gpg_id].nil? and opts[:gpg_opts][:aes_export].nil? and opts[:gpg_opts][:gpg_export].nil?  )
      repo_ok = !(opts[:repo_opts][:gpg_sign].nil?)

      gpg_ok and repo_ok
    end

    def self.log_level
      @@logger.level
    end

  end
end
