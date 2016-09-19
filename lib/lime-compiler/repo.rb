require 'active_support/core_ext/hash'
require 'digest'
require 'nokogiri'
require 'zlib'

module LimeCompiler
  class Repo

    def initialize opts = {}
      @primary_metadata = {}
      @repo_metadata = {}

      @metadata_dir = "repodata"
      @module_dir = "modules"
      @packager = opts['packager']
      @platform = opts['platform']

      @logger = Logger.new(STDOUT).tap do |log|
        log.progname = 'lime-compiler.repo'
      end
      @logger.level = Application.log_level
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

    def generate_metadata mod_path, sig_path

      metadata = {}

      module_name = mod_path.split("/")[-1]
      signature_name = sig_path.split("/")[-1]

      metadata[:name]      = module_name
      metadata[:arch]      = "x86_64" # TODO: make this dynamic
      metadata[:checksum]  = self.sha256 mod_path
      metadata[:version]   = self.mod_name module_name
      metadata[:packager]  = @packager
      metadata[:location]  = "#{@module_dir}/#{module_name}"
      metadata[:signature] = "#{@module_dir}/#{signature_name}"
      metadata[:platform]  = @platform

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

        # expand base directory to fully qualified path
        base = File.expand_path(base).chomp("/")

        repomd_xml = File.open(repomd_path, 'rb') { |f| Nokogiri::XML(f) }
        repomd = Hash.from_xml(repomd_xml.to_s)
        gzfile = "#{base}/#{repomd['metadata']['data']['location']['href']}"

        primary = nil
        @logger.debug "reading primary manifest #{gzfile}"
        Zlib::GzipReader.open(gzfile) do |gz|
          xml_string = gz.read
          primary = Hash.from_xml(xml_string)
        end

        self.merge_repos base, primary['modules']['module']
      end
    end

    def merge_repos base, modules
      modules.each do |mod|
        mod_path = "#{base.chomp("/")}/#{mod['location']['href']}"
        if !@primary_metadata.key?(mod_path) and File.file?(mod_path)
          @logger.debug "found #{mod_path} in existing primary.xml"
          @logger.debug "injecting module metadata for #{mod_path}"
          sig_path = "#{base}/#{mod['location']['href']}.sig"
          self.generate_metadata mod_path, sig_path
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

  end
end
