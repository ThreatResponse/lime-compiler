require 'logger'
require 'yaml'
require_relative 'cli'
require_relative 'compile_target'
require_relative 'local_system'

module LimeCompiler
  class Application

    def run

      cli = Cli.new
      opts = cli.options

      @@logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler'
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
      rescue Exception => e
        @@logger.fatal e.message
        @@logger.debug e.backtrace.inspect
        exit(1)
      end

      client = LimeCompiler::DockerClient.new(config['docker']['url'])

      config['images'].each do |name, image|
        unless image['image'] == 'local'
          @@logger.info "pulling latest for #{image['image']}:#{image['tag']}"
          client.pull(image['image'], image['tag'])
        end
      end

      config['images'].each do |name, image|

        if image['image'] == 'local'
          local_run = true
        else
          local_run = false
        end

        container_name = "lime_build_#{image['image']}_#{image['tag']}"
        distro_name = image['distribution']
        distro = config['distributions'][distro_name]

        if local_run
          c = LocalSystem.new
        else
          @@logger.info "creating container #{container_name} from #{image['image']}:#{image['tag']}"
          c = client.container(container_name, image['image'], image['tag'],
                               'start': true, 'reuse': true)
        end

        target = CompileTarget.new(name: container_name, archive_name: name,
                                   archive_dir: opts[:archive_dir],
                                   module_dir: opts[:module_dir],
                                   distro: distro, container: c)
        begin
          target.pre_actions
          target.update_sources
          target.install_dependencies
          target.clone_lime
          target.create_directories
          target.install_headers
          target.compile_lime
          target.write_archive
        rescue Exception => e
          @@logger.fatal e.message
          @@logger.debug e.backtrace.inspect
        end

        client.cleanup_container(c, delete: false, local_run: local_run)

      end

      client.cleanup_containers(delete: false)

    end

    def self.log_level
      @@logger.level
    end

  end
end
