require 'commander'

module LimeCompiler
  class Configure
    LIST_MESSAGE = "\nConfiguration is generated from the following sources:\n"\
                   "\n"\
                   "  1. command line flags\n"\
                   "  2. environment variables [NOTE: unimplemented]\n"\
                   "  3. user specified config file: `--config` option\n"\
                   "  4. default config file `~/.lime-compiler.conf`\n"\
                   "  5. default bundled configuration values\n".freeze

    def self.print(config)
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

      say(LIST_MESSAGE)
    end
  end
end
