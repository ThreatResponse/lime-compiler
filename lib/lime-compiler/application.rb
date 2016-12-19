require 'logger'
require 'yaml'
require_relative 'cli'
require_relative 'compile_target'
require_relative 'gpg'

module LimeCompiler
  class Application

    def run

      cli = Cli.new
      opts = cli.options

      @@logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler'
      end
      @@logger.formatter= proc do |severity, datetime, progname, msg|
        "#{datetime.strftime("%Y-%m-%dT%H:%M:%S%:z")} - #{progname} - #{severity} - #{msg}\n"
      end

      if opts[:verbose]
        @@logger.level = Logger::DEBUG
      else
        @@logger.level = Logger::INFO
      end

      begin
        @@logger.debug "validating options #{opts}"
        cli.validate opts
        config = YAML::load_file(opts[:config])
        config = self.symbolize config
      rescue Exception => e
        @@logger.fatal e.message
        @@logger.debug e.backtrace.inspect
        exit(1)
      end

      client = LimeCompiler::DockerClient.new(config[:docker][:url])
      repo_options = config[:repository]
      repo_options.merge!({gpgsign: opts[:gpgsign]})
      repo_options.merge!({gpgnoverify: opts[:gpgnoverify]})
      repo = Repo.new(repo_options)
      repo.setup_directories opts[:module_dir]
      existing_modules = repo.modules opts[:module_dir]
      @@logger.debug "existing modules found: #{existing_modules}"

      config[:images].each do |name, image|
        @@logger.info "pulling latest for #{image[:image]}:#{image[:tag]}"
        client.pull(image[:image], image[:tag])
      end

      if opts[:gpgsign]
        gpg = GPG.new(signer: opts[:gpgsigner])
      end

      errors = []
      config[:images].each do |name, image|

        container_name = "lime_build_#{image[:image]}_#{image[:tag]}"
        distro_name = image[:distribution]
        distro = config[:distributions][distro_name.to_sym]

        @@logger.info "creating container #{container_name} from #{image[:image]}:#{image[:tag]}"
        c = client.container(container_name, image[:image], image[:tag],
                               'start': true, 'reuse': true)

        target = CompileTarget.new(name: container_name, archive_name: name,
                                   archive_dir: opts[:archive_dir],
                                   module_dir: "#{opts[:module_dir]}/modules",
                                   distro: distro, container: c,
                                   existing_modules: existing_modules,
                                   build_all: opts[:build_all])
        begin
          target.pre_actions
          target.update_sources
          target.install_dependencies
          target.clone_lime
          target.create_directories
          target.compile_lime
          modules = target.write_archive clobber: opts[:build_all]
          @@logger.debug "exported kernel modules: #{modules}"

          if opts[:gpgsign]
            existing_modules.each do |mod|
              sig_path = gpg.sign(mod)
              repo.generate_metadata mod, sig_path
            end

            modules.each do |mod|
              sig_path = gpg.sign(mod, overwrite: opts[:build_all])
              repo.generate_metadata mod, sig_path
            end
          else
            sig_path = nil

            existing_modules.each do |mod|
              repo.generate_metadata mod, sig_path
            end

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
        repomd_path = repo.generate_repodata opts[:module_dir]
        @@logger.debug "generated repodata #{repomd_path}"
        if opts[:gpgsign]
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
