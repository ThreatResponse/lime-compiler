require 'gpgme'
require_relative 'crypto'
require_relative 's3'

module LimeCompiler
  class GPG
    def initialize(opts)
      @opts = opts
      if opts[:gpg_home]
        Dir.mkdir opts[:gpg_home] unless File.directory? opts[:gpg_home]
        GPGME::Engine.home_dir = opts[:gpg_home]
      end
      @passphrase = nil
      @crypto = GPGME::Crypto.new

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.gpg'
      end
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%dT%H:%M:%S%:z')} - #{progname} - #{severity} - #{msg}\n"
      end
      @logger.level = Application.log_level
    end

    def import_key
      crypto = Crypto.new
      s3 = nil
      @logger.debug "fetching aes ciphertext from #{@opts[:aes_export]}"
      if @opts[:aes_export][0..4] == 's3://'
        s3 ||= S3.new
        aes_ciphertext = s3.fetch_data(@opts[:aes_export]).unpack('m')[0]
      else
        aes_ciphertext = File.read(@opts[:aes_export]).unpack('m')[0]
      end

      @logger.debug "fetching gpg ciphertext from #{@opts[:gpg_export]}"
      if @opts[:gpg_export][0..4] == 's3://'
        s3 ||= S3.new
        gpg_ciphertext = s3.fetch_data(@opts[:gpg_export]).unpack('m')[0]
      else
        gpg_ciphertext = File.read(@opts[:gpg_export]).unpack('m')[0]
      end

      @logger.debug 'decrypting aes initialization vector with KMS'
      aes_info = YAML.safe_load(crypto.kms_decrypt(aes_ciphertext))
      @logger.debug 'decrypting aes key with KMS'
      aes_key = crypto.kms_decrypt aes_info[:dek], 'gpg-fingerprint' => @opts[:gpg_id]
      @logger.debug 'decrypting gpg key with openssl'
      gpg_data = YAML.safe_load(
        crypto.aes_decrypt(gpg_ciphertext, aes_key, aes_info[:aes_iv])
      )
      @logger.info "importing gpg key: #{@opts[:gpg_id]} from #{@opts[:gpg_export]}"
      @passphrase = gpg_data[:passphrase]
      GPGME::Key.import gpg_data[:gpg_key]
    end

    def sign(path, opts = {})
      overwrite = opts[:overwrite] || false
      sigpath = "#{path}.sig"
      if !File.file?(sigpath) || overwrite
        @logger.debug "signing #{path} with #{@opts[:gpg_id]}"
        File.open(path, 'r') do |f|
          contents = f.read
          File.open(sigpath, 'w+') do |sigfile|
            sig = @crypto.sign contents, mode: GPGME::SIG_MODE_DETACH,
                                         signer: @opts[:gpg_id],
                                         passphrase_callback: method(:passfunc),
                                         pinentry_mode: GPGME::PINENTRY_MODE_LOOPBACK
            sigfile.write(sig)
          end
        end
        sigpath
      else
        @logger.debug "verifying existing signature #{path} with #{@opts[:gpg_id]}"
        return sigpath if verify_signature path, sigpath
        @logger.debug "signature verification failed for #{path}, #{sigpath}"
        # TODO: raise an exception
        return ''
      end
    end

    def verify_signature(file, sig_file)
      sig = File.open(sig_file, &:read)
      data = File.open(file, &:read)
      retval = nil
      @crypto.verify(sig, signed_text: data) do |signature|
        @logger.debug signature
        retval = signature.valid?
      end
      retval
    end

    private

    def passfunc(_hook, uid_hint, _passphrase_info, _prev_was_bad, fd)
      @logger.debug "automatically supplying passphrase for #{uid_hint}: "
      io = IO.for_fd(fd, 'w')
      io.puts(@passphrase)
      io.flush
    end
  end
end
