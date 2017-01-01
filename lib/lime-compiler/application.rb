require 'logger'
require 'yaml'
require_relative 'cli'
require_relative 'compile_target'
require_relative 'gpg'

module LimeCompiler
  class Application

    def run

      cli = Cli.new
      config = cli.options

      @@logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler'
      end
      @@logger.formatter= proc do |severity, datetime, progname, msg|
        "#{datetime.strftime("%Y-%m-%dT%H:%M:%S%:z")} - #{progname} - #{severity} - #{msg}\n"
      end

      if config[:verbose]
        @@logger.level = Logger::DEBUG
      else
        @@logger.level = Logger::INFO
      end

      begin
        @@logger.debug "validating options #{config}"
        cli.validate config
        config[:config] = YAML::load_file(config[:config_path])
        config = self.symbolize config
      rescue Exception => e
        @@logger.fatal e.message
        @@logger.debug e.backtrace.inspect
        exit(1)
      end

      client = LimeCompiler::DockerClient.new(config[:config][:docker])
      repo = Repo.new(config[:repo_opts])
      existing_modules = repo.modules config[:repo_opts][:module_dir]
      @@logger.debug "existing modules found: #{existing_modules}"

      config[:config][:images].each do |name, image|
        @@logger.info "pulling latest for #{image[:image]}:#{image[:tag]}"
        client.pull(image[:image], image[:tag])
      end


      if config[:repo_opts][:gpg_sign]
        gpg = GPG.new(config[:gpg_opts])
        existing_modules.each do |mod|
          sig_path = gpg.sign(mod, overwrite: config[:repo_opts][:sign_all])
          repo.generate_metadata mod, sig_path
        end
      else
        sig_path = nil
        existing_modules.each do |mod|
          repo.generate_metadata mod, sig_path
        end
      end

      errors = []
      config[:config][:images].each do |name, image|

        container_name = "lime_build_#{image[:image]}_#{image[:tag]}"
        distro_name = image[:distribution]
        distro = config[:config][:distributions][distro_name.to_sym]

        @@logger.info "creating container #{container_name} from #{image[:image]}:#{image[:tag]}"
        c = client.container(container_name, image[:image], image[:tag],
                               'start': true, 'reuse': true)

        local_opts = { name: container_name, archive_name: name,
                       distro: distro, container: c,
                       existing_modules: existing_modules }

        target = CompileTarget.new(local_opts.merge!(config[:build_opts]))

        begin
          target.pre_actions
          target.update_sources
          target.install_dependencies
          target.clone_lime
          target.create_directories
          target.compile_lime
          modules = target.write_archive
          @@logger.debug "exported kernel modules: #{modules}"

          if config[:repo_opts][:gpg_sign]
            modules.each do |mod|
              sig_path = gpg.sign(mod, overwrite: config[:repo_opts][:sign_all])
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
          @@logger.fatal e.message
          @@logger.debug e.backtrace.inspect
        end
        client.cleanup_container(c, delete: false)
      end

      if errors.empty?
        repomd_path = repo.generate_repodata config[:repo_opts][:module_dir]
        @@logger.debug "generated repodata #{repomd_path}"
        if config[:repo_opts][:gpg_sign]
          repomd_sig_path = gpg.sign(repomd_path, overwrite: true)
          @@logger.debug "signed repo metadata #{repomd_sig_path}"
        end
      else
        @@logger.fatal "refusing to generate repo metadata due to the following errors #{errors}"
      end

      client.cleanup_containers(delete: false)

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

    def self.log_level
      @@logger.level
    end

  end
end
