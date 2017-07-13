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

      config = Configuration.new

      global_option('--config PATH ' ' Specify non-default config file.') { |path|
        config.user_config = path
      }
      #NOTE: seems to be a bug if both verbose and debug are specified (ordering matters) treating second flag as value of arg?
      global_option('--verbose' '      Log INFO level messages') {
        config.set_flag(:verbose, true)
      }
      #NOTE: seems to be a bug if both verbose and debug are specified (ordering matters) treating second flag as value of arg?
      global_option('--debug' '        Log DEBUG level messages') {
        config.set_flag(:debug, true)
      }

      command :'configure list' do |c|
        c.syntax = 'configure list'
        c.description = 'Inspect lime-compiler options'

        c.action do |args, options|
          say("\nlime-compiler configuration:")
          config.to_h.each do |section, section_config|
            say("\n[<%= color('#{section.to_s}', :blue) %>]")
            section_config.to_h.each do |key, value|
              if value.nil?
                value = "Not Configured"
              end
              if config.default?(section, key)
                value = "#{value} <%= color('[Default]', :bold) %>"
              end
              say("<%= color('#{key.to_s}', :green) %> = #{value}")
            end
          end

          say("\nThe configuration above is generated by merging data sources with the following precedence:")
          say("\n  1. command line flags")
          say("  2. environment variables [NOTE: unimplemented]")
          say("  3. user specified config file: `--config` option")
          say("  4. default config file `~/.lime-compiler.conf`")
          say("  5. default bundled configuration values")

        end
      end

      command :configure do |c|
        c.syntax = 'configure'
        c.description = 'Configure lime-compiler options'

        c.action do |args, options|
          puts "todo prompt user for configuration"
        end

      end

      run!
    end

  end
end
