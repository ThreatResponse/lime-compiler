require 'yaml'
require_relative 'cli'

module LimeCompiler
  class CompileTarget

    def initialize opts = {}
      @name = opts[:name]
      @distro = opts[:distro]
      @container = opts[:container]
      @packages = nil
      @prefix = @distro[:kernel_package_prefix] ||= ''
      @source_dir = @distro[:source_dir]
      @source_postfix = @distro[:kernel_source_postfix] ||= ''
      @archive_dir = opts[:archive_dir]
      @archive_name = "#{opts[:archive_name]}.tar"
      @module_dir = opts[:module_dir]
      @existing_modules = opts[:existing_modules]
      @build_all = opts[:build_all]
      @arch = @container.exec(['/bin/arch'])[0][0].strip

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.compile-target'
      end
      @logger.formatter= proc do |severity, datetime, progname, msg|
        "#{datetime.strftime("%Y-%m-%dT%H:%M:%S%:z")} - #{progname} - #{severity} - #{msg}\n"
      end
      @logger.level = Application.log_level
    end

    def pre_actions
      unless @distro[:pre_actions].nil?
        @logger.info "running pre actions for #{@name}"
        @distro[:pre_actions].each do |action|
          resp = @container.exec(action.split(" "), tty: true)
          @logger.debug resp[0]
        end
      end
    end

    def update_sources
      @logger.info "updating sources for #{@name}"
      resp = @container.exec([@distro[:packager], 'update'] + @distro[:packager_args], tty: true)
      @logger.debug resp
    end

    def install_dependencies
      @logger.info "installing dependecies for #{@name}"
      command = [@distro[:packager], 'install'] + @distro[:packager_args] + @distro[:dependencies]
      resp = @container.exec(command, tty: true)
      @logger.debug resp
    end

    def clone_lime
      @logger.info "cloning LiME to /tmp/LiME for #{@name}"
      resp = @container.exec("rm -rf /tmp/LiME".split(" ") , tty: true)
      @logger.debug resp

      command = "git clone --quiet https://github.com/504ensicsLabs/LiME.git /tmp/LiME".split(" ")
      resp = @container.exec(command , tty: true)
      @logger.debug resp
    end

    def create_directories
      @logger.info "creating module output dir /tmp/modules for #{@name}"
      command = "mkdir -p /tmp/modules".split(" ")
      resp = @container.exec(command , tty: true)
      @logger.debug resp
    end

    def compile_lime
      @logger.info "installing kernel headers for #{@name}"
      resp = @container.exec(@distro[:kernel_packages].split(" "), tty: true)
      @logger.debug resp
      @packages = kernel_packages(resp[0])
      @logger.debug @packages

      @packages = @packages.map {|val| "#{@prefix}#{val}"}
      @packages.each do |package|
        if @distro[:source_include_arch?]
          kernel = "#{package[@distro[:source_strip].length, package.length]}.#{@arch}"
        else
          kernel = "#{package[@distro[:source_strip].length, package.length]}"
        end

        if not module_built? kernel or @build_all
          unless package_installed? package
            command = [@distro[:packager], 'install'] + @distro[:packager_args] + [package]
            @logger.debug "running #{command}"
            resp = @container.exec(command, tty: true)
            @logger.debug resp
          end
          compile_for kernel
        else
          @logger.debug "skipping module for kernel #{kernel}, module already built"
        end
      end
    end

    def package_installed? package
      chk_package = @distro[:check_package]
      command =  chk_package[0, chk_package.length-1] + [chk_package.last + package]
      @logger.debug "running #{command}"
      resp = @container.exec(command, tty: true)
      @logger.debug resp
      if resp.last.zero?
        @logger.debug "#{package} already installed"
        return true
      else
        @logger.debug "#{package} not installed"
        return false
      end
    end

    def module_built? kernel
      @logger.debug("checking if kernel already built: #{kernel}")
      @existing_modules.include? "lime-#{kernel}.ko"
    end

    def compile_for kernel
      @logger.debug "compiling lime for #{kernel}"
      command = "make -C #{@source_dir}/#{kernel}#{@source_postfix} M=/tmp/LiME/src"
      resp = @container.exec(command.split(" "), tty: true)
      @logger.debug resp
      command = "mv /tmp/LiME/src/lime.ko /tmp/modules/lime-#{kernel}.ko"
      resp = @container.exec(command.split(" "), tty: true)
      @logger.debug resp
    end

    def write_archive clobber: false
      archive_path = File.join(File.expand_path(@archive_dir),@archive_name)
      @logger.info "writing modules to file #{archive_path}"
      File.open(archive_path, 'wb') do |file|
        @container.copy("/tmp/modules") do |chunk|
          file.write(chunk)
        end
      end

      extract_file_paths = []

      @logger.info "expanding archive: #{archive_path}"
      extract = Gem::Package::TarReader.new(File.open(archive_path, 'r'))
      extract.each do |entry|
        if entry.file?
          # strip one modules from the start of the file
          filename = entry.full_name.gsub(/^modules\//, '')

          path = File.join(File.expand_path(@module_dir),filename)
          # overwrite files only if clobber is true
          if !File.exists?(path) or clobber
            @logger.debug "writing #{path}"
            File.open(path, 'wb') do |f|
              f.write(entry.read)
            end
            extract_file_paths << path
          end
        end
      end

      extract_file_paths
    end

    def kernel_packages(output)
      packages = []

      pattern = Regexp.new(@distro[:kernel_package_match])
      match_position = @distro[:match_position]
      package_position = @distro[:kernel_position]
      output.each do |text|
        # some blocks of text contain multiple lines
        text.split("\r\n").each do |line|
          line = line.gsub("\r\n", '').strip.chomp
          tokens = line.split(" ")
          if tokens[match_position] =~ pattern
            package = tokens[package_position]
            packages << package
            @logger.debug "matched kernel: #{package}"
          else
            @logger.debug "match failed #{tokens[match_position]} for #{pattern}"
          end
        end
      end

      packages.sort.uniq
    end

  end
end
