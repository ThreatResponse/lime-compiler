require 'aws-sdk'

module LimeCompiler
  class S3
    def initialize
      @s3 = Aws::S3::Client.new
    end

    def fetch_data(uri, opts = {})
      opts = parse_uri uri if uri[0..4] == 's3://'
      resp = @s3.get_object(bucket: opts[:bucket], key: opts[:key])
      resp.body.read
    end

    def parse_uri(uri)
      path = uri[5..-1]
      parts = path.split('/')
      # TODO: raise exception if parts.length < 2, this means we don't have a uri
      #      that matches s3://bucket/key
      bucket = parts[0]
      key = parts[1..-1].join('/')
      { bucket: bucket, key: key }
    end
  end
end
