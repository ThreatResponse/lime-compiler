require 'logger'
require 'yaml'
require_relative 'cli'
require_relative 'compile_target'

module LimeCompiler
  class Application

    def run

      cli = Cli.new
      opts = cli.options

      begin
        cli.validate opts
        config = YAML::load_file(opts[:config])
      rescue Exception => e
        logger.fatal
        puts e.message
        exit(1)
      end

      puts opts


      exit

      client = LimeCompiler::DockerClient.new(config['docker']['url'])

      config['images'].each do |name, image|
        puts "pulling latest for #{image['image']}:#{image['tag']}"
        client.pull(image['image'], image['tag'])
      end

      # TODO: process images inline
      config['images'].each do |name, image|
        container_name = "lime_build_#{image['image']}_#{image['tag']}"
        distro_name = image['distribution']
        distro = config['distributions'][distro_name]

        # TODO: replace debug prints with nice info message
        #puts distro_name
        #puts distro

        c = client.container(container_name, image['image'], image['tag'],
                             'start': true, 'reuse': true)

        target = CompileTarget.new(container_name, name, distro, c)
        target.pre_actions
        target.update_sources
        target.install_dependencies
        target.clone_lime
        target.create_directories
        target.install_headers
        target.compile_lime
        target.write_archive

        client.cleanup_container(c, delete: false)

      end

      # TODO: call host cleanup just to be safe
      client.cleanup_containers(delete: false)

    end

  end
end
