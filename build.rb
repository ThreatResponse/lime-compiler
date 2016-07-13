#!/usr/bin/env ruby

require 'logger'
require 'docker'
require 'yaml'
require 'rubygems/package'

# TODO: temporary function definitions

def kernel_packages(output, distribution)
  packages = []

  match = distribution['kernel_package_match']
  match_position = distribution['match_position']
  package_position = distribution['kernel_position']

  output.each do |line|
    line.gsub!(/\x0A/, '').strip!.chomp!
    tokens = line.split(" ")
    if tokens[match_position].include? match
      package = tokens[package_position]
      packages << package
      @logger.debug "matched kernel: #{package}"
    else
      @logger.debug "match failed #{tokens[match_position]} for #{match}"
    end
  end

  packages
end

# TODO: function to get kernel headers from /lib/modules
def kernel_modules(output)
  modules = []
  output.each do |line|
    line.gsub!(/\x0A/, '').strip!.chomp!
    tokens = line.split(" ")
    tokens.each do |token|
      modules << token
    end
  end
  modules
end

# TODO: move to argument
lvl = Logger::DEBUG
#lvl = Logger::INFO

# Fedora location, move to environment variable
@logger = Logger.new(STDOUT)
@logger.level = lvl

# TODO: remove debug formatter:
@logger.formatter = proc do |severity, datetime, progname, msg|
  "#{msg}\n"
end

Docker.url = 'unix:///var/run/docker.sock'

# Set read/write timeouts
Excon.defaults[:write_timeout] = 2000
Excon.defaults[:read_timeout] = 2000

# load images from config file
config = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)),
                                   'config.yml'))

# load container ids from file
containers = {}
begin
  containers_config = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)),
                                                '_containers.yml'))
  containers_config.each do |key, value|
    containers.merge!({ key => Docker::Container.get(value[:id]) })
  end
rescue
  puts 'todo'
end

# TODO: remove debug print
puts containers
containers.each do |key, value|
  puts "#{key}: #{value.info['Name']}"
end
exit

distributions = config['distributions']
images = config['images']


images.each do |key, value|

  begin
    dockerhub_id = "#{value['image']}:#{value['tag']}"


    distro = distributions[value['distribution']]
    @logger.debug distro
    @logger.info "pulling latest from #{dockerhub_id}"
    image = Docker::Image.create('fromImage': dockerhub_id)
    # run commands here to install kernel modules
    # then save image
    @logger.debug "image id: #{image.id}"

    # keep our container running indefinately
    command = ["bash", "-c", "/usr/bin/tail -f /dev/null"]
    name = "#{dockerhub_id}-limebuild"
    begin
      container = Docker::Container.create("Cmd": command,
                                           "Image": image.id,
                                           "Tty": true)
      container.start
    rescue Exception => e
      # for now assume that the container already exists
      puts e
      exit
    end

    unless distro['pre_actions'].nil?
      @logger.info "running pre actions for #{dockerhub_id}"
      distro['pre_actions'].each do |action|
        resp = container.exec(action.split(" "), tty: true)
        @logger.debug resp
      end
    end

    @logger.info "updating sources for #{dockerhub_id}"
    resp = container.exec([distro['packager'], 'update', '-y'] , tty: true)
    @logger.debug resp

    @logger.info "installing dependecies for #{dockerhub_id}"
    # TODO: check if we need all of these
    command = [distro['packager'], 'install', '-y'] + distro['dependencies']
    resp = container.exec(command, tty: true)
    @logger.debug resp

    @logger.info "downloading lime to /LiME for #{dockerhub_id}"
    command = "git clone https://github.com/504ensicsLabs/LiME.git".split(" ")
    resp = container.exec(command , tty: true)
    @logger.debug resp

    @logger.info "creating module output dir /opt/modules"
    command = "mkdir -p /opt/modules".split(" ")
    resp = container.exec(command , tty: true)
    @logger.debug resp

    @logger.info "installing kernel headers"
    # get all kernel headers
    resp = container.exec(distro['kernel_packages'].split(" "), tty: true)
    @logger.debug resp

    packages = kernel_packages(resp[0], distro)
    @logger.debug packages

    prefix = distro['kernel_package_prefix'] ||= ''

    # TODO: move to individual install commands to avoid exec timeouts?
    packages = packages.map {|val| "#{prefix}#{val}"}
    command = [distro['packager'], 'install', '-y'] + packages
    @logger.debug command
    resp = container.exec(command, tty: true)
    @logger.debug resp

    # get all directories in /lib/modules
    source_dir = distro['source_dir']
    resp = container.exec(['ls', source_dir], tty: true)
    @logger.debug resp

    kernels = kernel_modules(resp[0])
    @logger.debug kernels

    source_postfix = distro['kernel_source_postfix'] ||= ''
    kernels.each do |kernel|
      @logger.debug "module: #{kernel}"
      command = "make -C #{source_dir}/#{kernel}#{source_postfix} M=/LiME/src"
      @logger.debug command
      resp = container.exec(command.split(" "), tty: true)
      @logger.debug resp
      command = "mv /LiME/src/lime.ko /opt/modules/lime-#{kernel}.ko"
      @logger.debug command
      resp = container.exec(command.split(" "), tty: true)
      @logger.debug resp
    end

    # TODO: remove debug print
    command = "ls /opt/modules".split(" ")
    resp = container.exec(command, tty: true)
    @logger.debug resp

    archive_path = "archive/#{value['image']}-#{value['tag']}.tar"
    @logger.info "writing modules to file #{archive_path}"
    File.open(archive_path, 'wb') do |file|
      container.copy("/opt/modules") do |chunk|
        file.write(chunk)
      end
    end

    @logger.info "expanding archive: #{archive_path}"
    # TODO: do this natively
    system("tar -xf #{archive_path}")

    container.stop
    container.delete

  rescue Exception => e
    @logger.warn e.message
    #@logger.warn e.backtrace.inspect.join("\n")
    @logger.warn e.backtrace.inspect
    unless container.nil?
      container.stop
      container.delete
    end
  end

end

