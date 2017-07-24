require 'commander'
require_relative 'version'
require_relative 'cmds/all'
require_relative 'configuration'

module LimeCompiler
  class Cli
    include Commander::Methods

    def run
      program :name, 'lime-compiler'
      program :version, LimeCompiler::VERSION
      program :description, 'lime kernel module build system'

      default_command :help

      config = Configuration.new

      global_option('--config PATH  Specify non-default config file.') do |path|
        config.user_config = path
      end

      global_option('--verbose') do
        config.set_flag(:verbose, true)
      end

      global_option('--debug') do
        config.set_flag(:debug, true)
      end

      command :'configure list' do |c|
        c.syntax = 'configure list'
        c.description = 'Inspect lime-compiler options'

        # c.action do |args, options|
        c.action do |_, _|
          Configure.list(config)
        end
      end

      command :configure do |c|
        c.syntax = 'configure'
        c.description = 'Configure lime-compiler options'

        # c.action do |args, options|
        c.action do |_, _|
          puts 'todo prompt user for configuration'
        end
      end

      run!
    end
  end
end
