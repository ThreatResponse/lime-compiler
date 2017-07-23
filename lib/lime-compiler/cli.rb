require 'commander'
require_relative 'version'
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
      # NOTE: seems to be a bug if both verbose and debug are specified (ordering matters) treating second flag as value of arg?
      global_option('--verbose      Log INFO level messages') do
        config.set_flag(:verbose, true)
      end
      # NOTE: seems to be a bug if both verbose and debug are specified (ordering matters) treating second flag as value of arg?
      global_option('--debug        Log DEBUG level messages') do
        config.set_flag(:debug, true)
      end

      command :'configure list' do |c|
        c.syntax = 'configure list'
        c.description = 'Inspect lime-compiler options'

        # c.action do |args, options|
        c.action do |_, _|
          say("\nlime-compiler configuration:")
          config.to_h.each do |section, section_config|
            say("\n[<%= color('#{section}', :blue) %>]")
            section_config.to_h.each do |key, value|
              value ||= 'Not Configured'
              if config.default?(section, key)
                value = "#{value} <%= color('[Default]', :bold) %>"
              end
              say("<%= color('#{key}', :green) %> = #{value}")
            end
          end

          say("\nConfiguration is generated from the following sources:")
          say("\n  1. command line flags")
          say('  2. environment variables [NOTE: unimplemented]')
          say('  3. user specified config file: `--config` option')
          say('  4. default config file `~/.lime-compiler.conf`')
          say('  5. default bundled configuration values')
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
