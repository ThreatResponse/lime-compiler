require 'gpgme'

module LimeCompiler
  class GPG

    def initialize opts = {}
      @signer = opts[:gpgid]
      @crypto = GPGME::Crypto.new

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.gpg'
      end
      @logger.level = Application.log_level
    end

    def sign path
      @logger.debug "signing #{path} with #{@signer}"
      sigpath = "#{path}.sig"
      File.open(path, 'r') do |f|
        contents = f.read
        File.open(sigpath, "w+") do |sigfile|
          sig = @crypto.sign contents, mode: GPGME::SIG_MODE_DETACH, signer: @signer
          sigfile.write(sig)
        end
      end
      sigpath
    end


  end
end
