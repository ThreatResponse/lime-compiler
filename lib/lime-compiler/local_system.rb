require 'open4'
require 'logger'
#require 'fileutils'

module LimeCompiler
  class LocalSystem

    def initialize
      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.compile-target'
      end
      @logger.level = Application.log_level
    end

    def exec command, opts = {}
      out = nil
      err = nil
      status = Open4::popen4(command.join(' ')) do |pid, stdin, stdout, stderr|
        out = stdout.read
        err = stdout.read
        @logger.debug "stdout: #{out}"
        @logger.debug "stderr: #{err}"
      end
      @logger.debug "exit status: #{status.exitstatus}"

      # return STDOUT, STDERR and exit code
      [out.split("\n"), err.split("\n"), status.exitstatus]
    end

    def copy path, &block
      tarfile = StringIO.new("")
      Gem::Package::TarWriter.new(tarfile) do |tar|
        Dir[File.join(path, "**/*")].each do |file|
          mode = File.stat(file).mode
          relative_file = file.sub /^#{Regexp::escape path}\/?/, ''

          if File.directory?(file)
            tar.mkdir relative_file, mode
          else
            tar.add_file relative_file, mode do |tf|
              File.open(file, "rb") { |f| tf.write f.read }
            end
          end

        end
      end
      tarfile.rewind
      yield tarfile.read
    end

  end
end
