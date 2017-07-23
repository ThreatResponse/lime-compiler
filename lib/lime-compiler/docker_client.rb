require 'docker'

module LimeCompiler
  class DockerClient
    attr_reader :containers, :images

    def initialize(opts)
      Docker.url = opts[:url]
      Excon.defaults[:write_timeout] = opts[:write_timeout]
      Excon.defaults[:read_timeout] = opts[:read_timeout]
      @commands = { park: ['bash', '-c', '/usr/bin/tail -f /dev/null'],
                    get_lime: ['git', 'clone',
                               'https://github.com/504ensicsLabs/LiME.git'],
                    create_output_dir: ['mkdir', '-p', '/opt/modules'] }
      @containers = []
      @images = []

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.docker-client'
      end
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%dT%H:%M:%S%:z')} - #{progname} - #{severity} - #{msg}\n"
      end
      @logger.level = Application.log_level
    end

    def pull(image, tag, opts = {})
      defaults = { 'register': true }
      opts = defaults.merge(opts)

      image = Docker::Image.create('fromImage' => "#{image}:#{tag}")
      @images << image.id if opts[:register]
      image
    end

    # TODO: raise a meaningful error when a container is already running
    #       shaemlessly refuse to build if the container is running
    def container(name, image, tag, opts = {})
      defaults = { command:  @commands[:park],
                   register: true,
                   start: false,
                   reuse: false }
      opts = defaults.merge(opts)

      begin
        container = Docker::Container.create('Image': "#{image}:#{tag}",
                                             'name' => name,
                                             'Cmd': opts[:command])
      rescue Docker::Error::ConflictError
        if opts[:reuse]
          @logger.info "container with name: #{name} already exists"
          @logger.info "re-using #{name}"
          container = Docker::Container.get(name)
        else
          @logger.fatal "container with  #{name} already exists"
          raise
        end
      end

      if opts[:start]
        @logger.info "starting #{name}"
        container.start
      end
      return container unless opts[:register]
      @containers << container.id

      container
    end

    def cleanup_container(container, opts = {})
      defaults = { 'delete': true }
      opts = defaults.merge(opts)

      name = container.info['Name']
      id = container.id
      container.refresh!
      @containers.delete(id)
      @logger.info "attempting to stop #{name}"
      container.stop if container.info['State'] == 'running'

      return unless opts[:delete]
      @logger.info "deleting #{name}"
      container.delete
    end

    def cleanup_containers(opts = {})
      Docker::Container.all.each do |container|
        cleanup_container(container, opts) if @containers.include? container.id
      end
    end
  end
end
