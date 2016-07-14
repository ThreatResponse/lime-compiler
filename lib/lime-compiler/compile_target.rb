require 'yaml'
require_relative 'cli'

module LimeCompiler
  class CompileTarget

    # TODO: uer configuratble archive path?
    def initialize name, archive_name, distro, container
      @name = name
      @distro = distro
      @container = container
      @packages = nil
      @prefix = distro['kernel_package_prefix'] ||= ''
      @source_dir = distro['source_dir']
      @source_postfix = distro['kernel_source_postfix'] ||= ''
      @archive_name = archive_name
    end

    # TODO: return stdout
    def pre_actions
      unless @distro['pre_actions'].nil?
        puts "running pre actions for #{@name}"
        @distro['pre_actions'].each do |action|
          resp = @container.exec(action.split(" "), tty: true)
          puts resp
        end
      end
    end

    def update_sources
      puts "updating sources for #{@name}"
      resp = @container.exec([@distro['packager'], 'update', '-y'] , tty: true)
      puts resp
    end

    def install_dependencies
      puts "installing dependecies for #{@name}"
      command = [@distro['packager'], 'install', '-y'] + @distro['dependencies']
      resp = @container.exec(command, tty: true)
      puts resp
    end

    def clone_lime
      puts "cloning LiME to /LiME for #{@name}"
      command = "git clone https://github.com/504ensicsLabs/LiME.git".split(" ")
      resp = @container.exec(command , tty: true)
      puts resp
    end

    def create_directories
      puts "creating module output dir /opt/modules for #{@name}"
      command = "mkdir -p /opt/modules".split(" ")
      resp = @container.exec(command , tty: true)
      puts resp
    end

    def install_headers
      puts "installing kernel headers for #{@name}"
      resp = @container.exec(@distro['kernel_packages'].split(" "), tty: true)
      puts resp
      @packages = kernel_packages(resp[0])
      puts @packages

      # TODO: move to individual install commands to avoid exec timeouts?
      @packages = @packages.map {|val| "#{@prefix}#{val}"}
      command = [@distro['packager'], 'install', '-y'] + @packages
      resp = @container.exec(command, tty: true)
      puts resp
    end

    def compile_lime
      resp = @container.exec(['ls', @source_dir], tty: true)
      puts resp

      kernels = kernel_modules(resp[0])
      puts kernels

      kernels.each do |kernel|
        puts "module: #{kernel}"
        command = "make -C #{@source_dir}/#{kernel}#{@source_postfix} M=/LiME/src"
        resp = @container.exec(command.split(" "), tty: true)
        puts resp
        command = "mv /LiME/src/lime.ko /opt/modules/lime-#{kernel}.ko"
        resp = @container.exec(command.split(" "), tty: true)
        puts resp
      end

    end

    def write_archive
      archive_path = "archive/#{@archive_name}.tar"
      puts "writing modules to file #{archive_path}"
      File.open(archive_path, 'wb') do |file|
        @container.copy("/opt/modules") do |chunk|
          file.write(chunk)
        end
      end

      # TODO: rework this big time
      puts "expanding archive: #{archive_path}"
      system("tar -xf #{archive_path} --keep-old-files")
    end

    def kernel_packages(output)
      packages = []

      match = @distro['kernel_package_match']
      match_position = @distro['match_position']
      package_position = @distro['kernel_position']

      output.each do |line|
        line.gsub!(/\x0A/, '').strip!.chomp!
        tokens = line.split(" ")
        if tokens[match_position].include? match
          package = tokens[package_position]
          packages << package
          puts "matched kernel: #{package}"
        else
          puts "match failed #{tokens[match_position]} for #{match}"
        end
      end

      packages
    end

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

  end
end
