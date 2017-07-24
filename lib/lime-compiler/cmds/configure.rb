require 'commander'
require_relative '../configuration'

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

    def self.interactive(config, opts = {})
      first_time(config) if opts[:first_time]
      return if opts[:first_time]

      finished = false
      save = false
      until finished
        choose do |menu|
          menu.prompt = 'Choose a configuration section:  '
          Configuration::CONFIG_SECTIONS.each do |section|
            menu.choice(section) { section(config, section) }
          end
          menu.choice('[discard config]') { finished = true }
          menu.choice('[save config]') { finished = true && save = true }
          menu.default = '[discard config]'
        end
      end

      return unless save
      config_path = ask('where shall we save this configuration?') do |q|
        q.default = '~/.lime-compiler'
      end
      config.save!(config_path)
    end

    def self.first_time(config)
      say(' Lets start with required configuration:')
      section(config, :build)
      section(config, :repo)

      sign_conf = ask(' Do you plan to sign kernel modules? [Y/n] ') do |q|
        q.validate = /(y|Y|n|N)/
      end
      section(config, :repo_signing) if sign_conf.casecmp 'y'

      say(' The rest of this configuration is optional')
      log_conf = ask(' Would you like to configure logging? [Y/n] ') do |q|
        q.validate = /(y|Y|n|N)/
      end
      section(config, :common) if log_conf.casecmp 'y'

      aws_conf = ask(' Would you like to aws credentiasl? [Y/n] ') do |q|
        q.validate = /(y|Y|n|N)/
      end
      section(config, :aws) if aws_conf.casecmp 'y'

      docker_conf = ask(' Would you like to configure docker? [Y/n] ') do |q|
        q.validate = /(y|Y|n|N)/
      end
      section(config, :docker) if docker_conf.casecmp 'y'
    end

    def self.section(config, section)
      say("NOOP configuring: #{config} #{section}")
    end
  end
end
