require 'lime-compiler/configuration'

describe LimeCompiler::Configuration do

  context "creating" do
    context "given a new configuration" do
      config = LimeCompiler::Configuration.new
      it "responds to config sections messages" do
        LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
          expect(config.respond_to?(section)).to eq(true)
        end
      end

      it "has default config sections" do
        LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
          expect(config.send(section)).not_to eq(nil)
        end
      end
    end
  end

  describe "#reload!" do
    context "given a modified configuration" do
      config = LimeCompiler::Configuration.new
      default = config.common.verbose
      config.common.verbose = !default

      context "after calling #reload!" do
        it "resets modified configuration" do
          config.reload!
          expect(config.common.verbose).to eq(default)
        end
      end
    end
  end

  describe "#set_flag" do
    context "given name ':verbose' and value 'true'" do
      config = LimeCompiler::Configuration.new
      it "stores the flag" do
        expect(config.common.verbose).to eq(false)

        config.set_flag(:verbose, true)
        expect(config.common.verbose).to eq(true)
      end

      it "persists the flag on #reload!" do
        config.reload!
        expect(config.common.verbose).to eq(true)
      end
    end
  end

  describe "#to_h" do
    context "given a new configuration" do

      config = LimeCompiler::Configuration.new

      it "it responds to #to_h" do
        expect(config.respond_to?("to_h")).to eq(true)
      end

      context "the result of calling #to_h" do
        config_hash = config.to_h
        it "should be a Hash" do
          expect(config_hash).to be_instance_of(Hash)
        end

        it "should contain all configuration sections" do
          LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
            expect(config_hash.key?(section)).to eq(true)
          end
        end

        it "should contain all section keys" do
          LimeCompiler::Configuration::CONFIG_SECTIONS.each do |section|
            LimeCompiler::Configuration::SECTION_KEYS[section].each do |key|
              expect(config_hash[section].key?(key.to_sym)).to eq(true)
            end
          end
        end

      end
    end
  end

end
