require 'active_support/core_ext/hash'
require 'digest'
require 'gpgme'
require 'nokogiri'
require 'zlib'

module LimeCompiler
  class Repo

    def initialize opts
      @opts = opts
      @primary_metadata = {}
      @repo_metadata = {}
      @base_path = opts[:module_dir].chomp("/")
      @metadata_dir = "repodata"
      @module_dir = "modules"
      if opts[:gpg_home]
        GPGME::Engine.home_dir = opts[:gpg_home]
      end
      @crypto = GPGME::Crypto.new

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.repo'
      end
      @logger.formatter= proc do |severity, datetime, progname, msg|
        "#{datetime.strftime("%Y-%m-%dT%H:%M:%S%:z")} - #{progname} - #{severity} - #{msg}\n"
      end
      @logger.level = Application.log_level

      setup_directories @base_path
    end

    def setup_directories path
      metadata_path = "#{path}/#{@metadata_dir}"
      module_path = "#{path}/#{@module_dir}"

      unless File.directory? metadata_path
        @logger.debug "creating dir #{metadata_path}"
        Dir.mkdir metadata_path
      end
      unless File.directory? module_path
        @logger.debug "creating dir #{module_path}"
        Dir.mkdir "#{module_path}"
      end
    end

    def modules
      module_path = "#{@base_path}/#{@module_dir}"
      Dir["#{module_path.chomp("/")}/*.ko"].map { |val| File.absolute_path(val) }
    end

    def generate_metadata mod_path, sig_path

      metadata = {}

      module_name = mod_path.split("/")[-1]
      if sig_path.nil?
        signature_path = ""
      else
        signature_path = "#{@module_dir}/#{sig_path.split("/")[-1]}"
      end

      metadata[:name]      = module_name
      metadata[:arch]      = "x86_64" # TODO: make this dynamic
      metadata[:checksum]  = self.sha256 mod_path
      metadata[:version]   = self.mod_name module_name
      metadata[:packager]  = @opts[:packager]
      metadata[:location]  = "#{@module_dir}/#{module_name}"
      metadata[:signature] = signature_path
      metadata[:platform]  = @opts[:platform]

      @logger.debug "generated metadata #{metadata} for #{mod_path}"
      @primary_metadata[mod_path] = metadata
    end

    def generate_repodata base
      @logger.debug "checking for existing repomd.xml before overwrite"
      self.check_repomd base

      primary_path = self.write_primary_metadata base
      primary_checksum = self.sha256 primary_path

      result = self.rename primary_path, primary_checksum

      gzip_path = "#{result[:path]}.gz"
      gzip_filename = "#{result[:filename]}.gz"

      timestamp = self.compress result[:path], result[:filename], gzip_path

      repodata = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.metadata {
          xml.revision Time.now.to_i
          xml.data(type: "primary") {
            xml.checksum self.sha256 gzip_path
            xml.open_checksum primary_checksum
            xml.location(href: "#{@metadata_dir}/#{gzip_filename}")
            xml.timestamp timestamp.to_i
            xml.size File.size(gzip_path)
            xml.open_size File.size(result[:path])
          }
        }
      end

      # write repo metadata
      repomd_path = "#{base.chomp("/")}/#{@metadata_dir}/repomd.xml"
      @logger.debug "generating repomd.xml at #{repomd_path}"
      File.open(repomd_path, 'wb') { |file| file.write(repodata.to_xml) }

      # remove uncompressed primary.xml
      @logger.debug "removing intermediate primary metadata at #{result[:path]}"
      File.delete(result[:path])

      repomd_path
    end

    def rename path, checksum
      new_path = path.split("/")
      new_filename = "#{checksum}-#{new_path[-1]}"
      new_path[-1] = new_filename
      new_path = new_path.join("/")
      @logger.debug "renaming #{path} to #{new_path}"
      File.rename(path, new_path)

      {path: new_path, filename: new_filename}
    end

    def compress path, filename, gzip_path
      timestamp = nil

      @logger.debug "compressing #{path} to #{gzip_path}"
      Zlib::GzipWriter.open(gzip_path) do |gz|
        timestamp = File.mtime(path)
        gz.mtime = timestamp
        gz.orig_name = filename
        gz.write IO.binread(path)
      end

      timestamp
    end

    def write_primary_metadata base
      primary = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.modules {
          @primary_metadata.each do |k, v|
            xml.module(type: "lime") {
              xml.name v[:name]
              xml.arch v[:arch]
              xml.checksum v[:checksum]
              xml.version v[:version]
              xml.packager v[:packager]
              xml.location(href: v[:location])
              xml.signature(href: v[:signature])
              xml.platform v[:platform]
            }
          end
        }
      end
      primary_path = "#{base.chomp("/")}/#{@metadata_dir}/primary.xml"
      @logger.debug "writting module metadata to #{primary_path}"
      File.open(primary_path, 'wb') { |file| file.write(primary.to_xml) }
      primary_path
    end

    def check_repomd base
      repomd_path = "#{base.chomp("/")}/#{@metadata_dir}/repomd.xml"
      if File.file? repomd_path
        @logger.debug "found existing repomd.xml at #{repomd_path}"

        # validate signature for repodata.xml
        if @opts[:gpg_sign] and !@opts[:gpg_no_verify]
          @logger.debug "checking gpg signature for #{repomd_path}"
          repomd_sig_path = "#{repomd_path}.sig"

          if File.file? repomd_sig_path
            sig_pass = self.verify_signature repomd_path, repomd_sig_path
          else
            @logger.warn "repomd.xml signature not found, expected #{repomd_sig_path}, use the '--gpg-no-verify' flag to bypass check"
            sig_pass = false
          end

          # on verification failure return from function
          if sig_pass == false
            @logger.warn "ignoring existing repomd.xml, signature verification failed for #{repomd_path}"
            return
          end

        else
          @logger.debug "gpg signing disabled, skipping check of repomd.xml signature"
        end

        # expand base directory to fully qualified path
        base = File.expand_path(base).chomp("/")

        repomd_xml = File.open(repomd_path, 'rb') { |f| Nokogiri::XML(f) }
        repomd = Hash.from_xml(repomd_xml.to_s)
        gzfile = "#{base}/#{repomd['metadata']['data']['location']['href']}"

        # verify gzipped checksum
        gz_checksum = repomd['metadata']['data']['checksum']
        @logger.debug "verifying checksum: #{gzfile}"
        if self.checksum_matches gzfile, gz_checksum
          primary = nil
          xml_string = nil
          @logger.debug "reading primary manifest #{gzfile}"
          Zlib::GzipReader.open(gzfile) do |gz|
            xml_string = gz.read
            primary = Hash.from_xml(xml_string)
          end

          # verify open_checksum
          @logger.debug "verifying decompressed data checksum: #{gzfile}"
          open_checksum = repomd['metadata']['data']['open_checksum']
          if self.checksum_matches xml_string, open_checksum, {is_file: false}
            @logger.debug "verification complete, merging #{gzfile}"
            self.merge_repos base, primary['modules']['module']
          else
            msg = "expected #{open_checksum} for #{gzfile}"
            @logger.info "existing primary manifest open checksum mismatch, #{msg}"
          end
        else
          msg = "expected #{gz_checksum} for #{gzfile}"
          @logger.info "existing primary manifest checksum mismatch, #{msg}"
        end

        if File.file? gzfile
          @logger.debug "cleaning up old primary.xml #{gzfile}"
          File.delete(gzfile)
        end
      end
    end

    def merge_repos base, modules
      modules.each do |mod|
        mod_path = "#{base.chomp("/")}/#{mod['location']['href']}"
        if !@primary_metadata.key?(mod_path) and File.file?(mod_path)
          @logger.debug "found #{mod_path} in existing primary.xml"

          # verify module signature if present
          if mod['signature']['href'] != ""
            @logger.debug "verifying module signature #{mod_path}"
            sig_path = "#{base}/#{mod['location']['href']}.sig"

            if self.verify_signature mod_path, sig_path
              sig_pass = true
              sig_attempt_verify = true
            else
              sig_pass = false
              sig_attempt_verify = true
            end

          else
            sig_pass = true
            sig_verify = false
          end

          # verify kernel module checksum
          @logger.debug "verifying module checksum #{mod_path}"
          checksum_pass = self.checksum_matches mod_path, mod['checksum']

          # only insert module if verification passes
          if sig_pass and checksum_pass
            @logger.debug "injecting module metadata for #{mod_path}"
            self.generate_metadata mod_path, sig_path
          else
            sig = sig_pass and sig_attempt_verify
            msg = "signature valid: #{sig}, checksum valid: #{checksum_pass}"
            @logger.info "module verification failed, #{msg} for #{mod_path}"
          end
        end
      end
    end

    def mod_name mod
      name = mod
      ["lime-", ".ko"].each do |s|
        name = name.gsub(s, "")
      end

      name
    end

    def sha256 path
      Digest::SHA256.hexdigest File.read path
    end

    def primary_metadata
      @primary_metadata
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

    def checksum_matches data, checksum, opts = {is_file: true}
      if opts[:is_file]
        calculated = self.sha256 data
        @logger.debug "calculated checksum #{calculated}"
        result = checksum.eql?(calculated)
      else
        calculated = Digest::SHA256.hexdigest data
        @logger.debug "calculated checksum #{calculated}"
        result = checksum.eql?(calculated)
      end
      result
    end

  end
end
