require 'gpgme'
require_relative 'crypto'

module LimeCompiler
  class GPG

    def initialize opts
      @opts = opts
      if opts[:gpg_home]
        GPGME::Engine.home_dir = opts[:gpg_home]
      end
      @crypto = GPGME::Crypto.new

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.gpg'
      end
      @logger.formatter= proc do |severity, datetime, progname, msg|
        "#{datetime.strftime("%Y-%m-%dT%H:%M:%S%:z")} - #{progname} - #{severity} - #{msg}\n"
      end
      @logger.level = Application.log_level
    end

    def import_key kms_opts
      crypto = Crypto.new kms_opts
      aes_ciphertext = File.read(@opts[:aes_export]).unpack('m')[0]
      gpg_ciphertext = File.read(@opts[:gpg_export]).unpack('m')[0]
      aes_info = YAML::load(crypto.kms_decrypt aes_ciphertext)
      aes_key = crypto.kms_decrypt aes_info[:dek], {"gpg-fingerprint" => @opts[:gpg_id]}
      gpg_key_data = crypto.aes_decrypt gpg_ciphertext, aes_key, aes_info[:aes_iv]
      GPGME::Key.import gpg_key_data
    end

    def sign path, opts = {}
      overwrite = opts[:overwrite] || false
      sigpath = "#{path}.sig"
      if !File.file? sigpath or overwrite
        @logger.debug "signing #{path} with #{@opts[:gpg_id]}"
        File.open(path, 'r') do |f|
          contents = f.read
          File.open(sigpath, "w+") do |sigfile|
            sig = @crypto.sign contents, mode: GPGME::SIG_MODE_DETACH, signer: @opts[:gpg_id]
            sigfile.write(sig)
          end
        end
        sigpath
      else
        @logger.debug "verifying existing signature #{path} with #{@opts[:gpg_id]}"
        if self.verify_signature path, sigpath
          return sigpath
        else
          @logger.debug "signature verification failed for #{path}, #{sigpath}"
          #TODO: raise an exception
          return ""
        end
      end
    end

    def verify_signature file, sig_file
      sig = File.open(sig_file, 'r') {|f| f.read }
      data = File.open(file, 'r') {|f| f.read }
      retval = nil
      @crypto.verify(sig, signed_text: data) do |signature|
        @logger.debug signature
        retval = signature.valid?
      end
      retval
    end

  end
end
