require 'tempfile'
require 'lime-compiler/configuration'

describe LimeCompiler::Configuration do
  context 'creating' do
    context 'given a new configuration' do
      config = LimeCompiler::Configuration.new
      it 'responds to config sections messages' do
        LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
          expect(config.respond_to?(section)).to eq(true)
        end
      end

      it 'has default config sections' do
        LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
          expect(config.send(section)).not_to eq(nil)
        end
      end
    end
  end

  describe '#reload!' do
    context 'given a modified configuration' do
      config = LimeCompiler::Configuration.new
      default = config.common.verbose
      config.common.verbose = !default

      context 'after calling #reload!' do
        it 'resets modified configuration' do
          config.reload!
          expect(config.common.verbose).to eq(default)
        end
      end
    end
  end

  describe '#set_flag' do
    context "given name ':verbose' and value 'true'" do
      config = LimeCompiler::Configuration.new
      it 'stores the flag' do
        config.common.verbose = false

        config.set_flag(:verbose, true)
        expect(config.common.verbose).to eq(true)
      end

      it 'persists the flag on #reload!' do
        config.reload!
        expect(config.common.verbose).to eq(true)
      end
    end
  end

  describe '#to_h' do
    context 'given a new configuration' do
      config = LimeCompiler::Configuration.new

      it 'it responds to #to_h' do
        expect(config.respond_to?('to_h')).to eq(true)
      end

      context 'the result of calling #to_h' do
        config_hash = config.to_h
        it 'should be a Hash' do
          expect(config_hash).to be_instance_of(Hash)
        end

        it 'should contain all configuration sections' do
          LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
            expect(config_hash.key?(section)).to eq(true)
          end
        end

        it 'should contain all section keys' do
          LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
            LimeCompiler::Configuration::SECTION_KEYS[section].each do |key|
              expect(config_hash[section].key?(key.to_sym)).to eq(true)
            end
          end
        end
      end
    end
  end

  describe '.from_ini' do
    describe "a syntactically correct configuration file" do
      user_conf_verbose = true
      user_conf_debug = true

      user_conf = Tempfile.new('user-config')
      user_conf << "[common] \n"
      user_conf << "verbose = #{user_conf_verbose}\n"
      user_conf << "debug = #{user_conf_debug}\n"
      user_conf.flush

      it "should be loadable" do
        config = LimeCompiler::Configuration.from_ini(user_conf.path)
        expect(config).not_to eq(nil)
      end

      context "loaded from disk" do
        config = LimeCompiler::Configuration.from_ini(user_conf.path)

        it "should contain configs from the file" do
          expect(config.common.verbose).to eq(user_conf_verbose)
          expect(config.common.debug).to eq(user_conf_debug)
        end
      end
    end
  end

  describe '#merge!' do
    describe "given two differing configurations" do
      config_a = LimeCompiler::Configuration.new
      config_b = LimeCompiler::Configuration.new
      default_verbose = config_b.common.verbose
      default_debug = config_b.common.debug
      config_b.common.verbose = !default_verbose
      config_b.common.debug = !default_debug

      it "#merge should modify config_a with values from config_b" do
        config_a.merge!(config_b)
        expect(config_a.common.verbose).to eq(config_b.common.verbose)
        expect(config_a.common.debug).to eq(config_b.common.debug)
      end

    end
  end
end
