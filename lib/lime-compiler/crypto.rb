require 'aws-sdk'

module LimeCompiler
  class Crypto

    def initialize opts
      @kms = Aws::KMS::Client.new(region: opts[:kms_region])
    end

    def kms_decrypt data, encryption_context = nil
      puts encryption_context
      @kms.decrypt(ciphertext_blob: data,
                   encryption_context: encryption_context
                  ).plaintext
    end

    def aes_decrypt ciphertext, key, iv
      #TODO: set this up as a defualt option?
      alg = "AES-256-CBC"
      cipher = OpenSSL::Cipher::Cipher.new(alg)
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      plaintext = cipher.update(ciphertext)
      plaintext << cipher.final
    end

  end
end
